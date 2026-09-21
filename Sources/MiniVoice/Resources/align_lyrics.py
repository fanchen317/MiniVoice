"""Local forced alignment; preserve unmatched text instead of inventing timing."""
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import traceback


class AlignmentFailure(Exception):
    pass


def validated_segments(lines, segments, duration):
    if len(lines) != len(segments):
        raise AlignmentFailure("歌词分段未能完整匹配。请检查歌词是否与当前歌曲版本一致，或先保存原文。")
    output = []
    previous = -1.0
    for line, segment in zip(lines, segments):
        same_text = "".join(segment.text.split()) == "".join(line.split())
        start, end = float(segment.start), float(segment.end)
        valid = (same_text and math.isfinite(start) and math.isfinite(end) and start >= 0 and
                 round(start, 2) > previous and end - start >= 0.04 and end <= duration + 0.5)
        output.append({"text": line, "start": start if valid else None, "end": end if valid else None})
        if valid:
            previous = round(start, 2)
    return output


def ensure_coverage(segments):
    matched = sum(segment["start"] is not None for segment in segments)
    if not segments or matched / len(segments) < 0.65:
        raise AlignmentFailure("较多歌词未能匹配当前音频。请检查是否为现场版、是否缺少或多出段落；可以先保存文本，稍后再同步。")


def retry_missing(model, audio, segments, language, status):
    """Use surrounding reliable timestamps to re-run inference over bounded audio clips."""
    index = 0
    duration = len(audio) / 16000
    while index < len(segments):
        if segments[index]["start"] is not None:
            index += 1
            continue
        first = index
        while index < len(segments) and segments[index]["start"] is None:
            index += 1
        left = segments[first - 1]["end"] if first else 0
        right = segments[index]["start"] if index < len(segments) else duration
        if index - first > 6 or not 0.2 < right - left <= 60:
            continue
        status(f"正在重新匹配第 {first + 1}–{index} 行…")
        lines = [segment["text"] for segment in segments[first:index]]
        try:
            result = model.align(audio[int(left * 16000):int(right * 16000)], "\n".join(lines),
                                 language=language, original_split=True, regroup=False,
                                 verbose=None, nonspeech_skip=None)
            if result is None:
                continue
            replacements = validated_segments(lines, result.segments, right - left)
            for offset, replacement in enumerate(replacements):
                if replacement["start"] is not None:
                    replacement["start"] = round(replacement["start"] + left, 2)
                    replacement["end"] = round(replacement["end"] + left, 2)
                    # A replacement may touch a neighbouring boundary but must not overrun it.
                    if replacement["end"] <= right and replacement["start"] < right:
                        segments[first + offset] = replacement
        except Exception:
            traceback.print_exc()
    # Keep cents strictly ordered even after segment retries.
    previous = -1.0
    for segment in segments:
        if segment["start"] is not None:
            if round(segment["start"], 2) <= previous:
                segment["start"] = segment["end"] = None
            else:
                previous = round(segment["start"], 2)
    return segments


def main():
    request_path, output_path, status_path = map(Path, sys.argv[1:4])
    request = json.loads(request_path.read_text(encoding="utf-8"))

    def status(message):
        temporary = status_path.with_suffix(".tmp")
        temporary.write_text(message, encoding="utf-8")
        os.replace(temporary, status_path)

    status("正在读取歌曲音频…")
    import numpy as np
    raw = output_path.with_suffix(".audio.raw")
    # Decode completely before inference. No early pipe closure, and recoverable FLAC
    # frame warnings do not turn a usable full-length waveform into a failed import.
    decoded = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-err_detect", "ignore_err",
                              "-i", request["audioPath"], "-map", "0:a:0", "-vn",
                              "-ar", "16000", "-ac", "1", "-f", "f32le", str(raw)],
                             stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if decoded.stderr:
        print(decoded.stderr.decode("utf-8", errors="replace"), file=sys.stderr)
    if not raw.exists() or raw.stat().st_size < 6400:
        raise AlignmentFailure("无法读取这首歌曲的音频。请确认文件完整且能够正常播放，再重试同步。")
    audio = np.fromfile(raw, dtype=np.float32)
    duration = len(audio) / 16000
    if not np.isfinite(audio).all() or duration < request["duration"] - max(3, request["duration"] * 0.03):
        raise AlignmentFailure("歌曲音频未能完整解码，暂时无法可靠同步。请更换完整音频文件，或先保存歌词文本。")
    status("正在加载 AI 模型（首次使用需要下载约 460 MB）…")
    import stable_whisper
    import torch
    torch.set_num_threads(max(1, min(4, os.cpu_count() or 1)))
    model = stable_whisper.load_model("small", device="cpu", download_root=request["modelDirectory"])
    status("正在分析歌曲并匹配歌词…")

    def progress(current, total):
        if total:
            status(f"正在匹配歌词… {min(99, int(current / total * 100))}%")

    result = model.align(audio, "\n".join(request["lines"]), language=request["language"],
                         original_split=True, regroup=False, verbose=False, progress_callback=progress)
    if result is None:
        raise AlignmentFailure("未找到可用的歌词时间轴。请检查歌词版本，或先保存文本。")
    segments = validated_segments(request["lines"], result.segments, min(duration, request["duration"]))
    if any(segment["start"] is None for segment in segments):
        segments = retry_missing(model, audio, segments, request["language"], status)
    ensure_coverage(segments)
    output_path.write_text(json.dumps(segments, ensure_ascii=False, allow_nan=False), encoding="utf-8")
    status("歌词匹配完成")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        traceback.print_exc()
        message = str(error) if isinstance(error, AlignmentFailure) else "本地 AI 未能完成同步。请稍后重试，或先保存歌词文本。"
        Path(sys.argv[2]).with_suffix(".error.json").write_text(json.dumps({"message": message}, ensure_ascii=False), encoding="utf-8")
        sys.exit(1)
