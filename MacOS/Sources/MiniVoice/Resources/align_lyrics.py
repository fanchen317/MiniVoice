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



def _number(value):
    """Booleans and non-finite values are never valid model timestamps."""
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def validated_words(text, words, start, end, minimum_probability=0.35):
    """Keep measured model words only, mapped back onto the exact source string.

    Alignment tokenization can move spaces but may not alter or drop characters.
    No character timestamps are invented for multi-character model words.
    """
    if not (_number(start) and _number(end) and 0 <= start < end):
        return []
    measured = []
    for word in words or []:
        token = getattr(word, "word", None)
        if token is None:
            token = getattr(word, "text", None)
        if not isinstance(token, str):
            return []
        compact = "".join(token.split())
        if not compact:
            continue
        begin, finish = getattr(word, "start", None), getattr(word, "end", None)
        probability = getattr(word, "probability", None)
        if (not _number(begin) or not _number(finish) or begin < start - 0.02 or
                finish > end + 0.02 or finish - begin < 0.02 or
                measured and begin < measured[-1]["end"] - 0.02):
            return []
        if probability is not None and (not _number(probability) or
                                        not minimum_probability <= probability <= 1):
            return []
        entry = {"compact": compact, "start": max(start, begin), "end": min(end, finish)}
        if measured:
            # Only absorb a rounding-sized overlap, never stretch an invalid word.
            entry["start"] = max(entry["start"], measured[-1]["end"])
        if entry["end"] - entry["start"] < 0.02 - 1e-9:
            return []
        if probability is not None:
            entry["probability"] = probability
        measured.append(entry)
    if not measured or "".join(row["compact"] for row in measured) != "".join(text.split()):
        return []
    cursor = 0
    output = []
    for index, row in enumerate(measured):
        first, remaining = cursor, len(row["compact"])
        while cursor < len(text) and remaining:
            if not text[cursor].isspace():
                remaining -= 1
            cursor += 1
        # Preserve all original whitespace, attached to the preceding measured word.
        while cursor < len(text) and text[cursor].isspace():
            cursor += 1
        if index == len(measured) - 1:
            cursor = len(text)
        entry = {"text": text[first:cursor], "start": round(row["start"], 4),
                 "end": round(row["end"], 4)}
        if "probability" in row:
            entry["probability"] = row["probability"]
        output.append(entry)
    return output if "".join(row["text"] for row in output) == text else []


def word_alignment_windows(lines, anchors, duration, coarse=None):
    """Use real line anchors as hard boundaries; missing anchors need model evidence."""
    if not _number(duration) or duration <= 0 or not lines or len(lines) > 2000:
        raise AlignmentFailure("逐字分析缺少有效歌词或歌曲时长。")
    if any(not isinstance(line, str) or not line.strip() or "\n" in line or "\r" in line for line in lines):
        raise AlignmentFailure("逐字分析的歌词分行无效。")
    if anchors is None:
        anchors = [None] * len(lines)
    if not isinstance(anchors, list) or len(anchors) != len(lines):
        raise AlignmentFailure("已有歌词时间点数量不一致。")
    previous = -1.0
    for anchor in anchors:
        if anchor is None:
            continue
        if not _number(anchor) or anchor < 0 or anchor >= duration or anchor <= previous:
            raise AlignmentFailure("已有歌词时间点无效或发生倒退。")
        previous = anchor
    if coarse is not None and len(coarse) != len(lines):
        raise AlignmentFailure("歌词分段未能完整匹配。")
    starts = list(anchors)
    for index, anchor in enumerate(anchors):
        if anchor is not None or coarse is None:
            continue
        segment = coarse[index]
        candidate = getattr(segment, "start", None)
        text = getattr(segment, "text", None)
        left = next((value for value in reversed(starts[:index]) if value is not None), -1.0)
        right = next((value for value in anchors[index + 1:] if value is not None), duration)
        if (isinstance(text, str) and "".join(text.split()) == "".join(lines[index].split()) and
                _number(candidate) and 0 <= candidate < duration and left < candidate < right):
            starts[index] = candidate
    windows = []
    for index, start in enumerate(starts):
        if start is None:
            windows.append(None)
            continue
        end = next((value for value in starts[index + 1:] if value is not None), duration)
        if anchors[index] is None and coarse is not None:
            coarse_end = getattr(coarse[index], "end", None)
            if _number(coarse_end) and coarse_end > start:
                end = min(end, coarse_end)
        windows.append({"text": lines[index], "start": start, "end": end} if end - start >= 0.04 else None)
    return windows


def align_word_rows(model, audio, request, status):
    """Stable-ts 2.19.1 align_words confines each lyric to its known audio range."""
    lines, duration = request["lines"], min(len(audio) / 16000, request["duration"])
    anchors = request.get("anchors")
    # Validate supplied anchors before starting any inference.
    word_alignment_windows(lines, anchors, duration)
    supplied = anchors if anchors is not None else [None] * len(lines)
    coarse = None
    if any(value is None for value in supplied):
        status("正在建立缺失的逐行音频边界…")
        result = model.align(audio, "\n".join(lines), language=request["language"],
                             original_split=True, regroup=False, verbose=None,
                             nonspeech_skip=None)
        if result is None:
            raise AlignmentFailure("未找到可靠的逐行音频边界。")
        coarse = result.segments
    windows = word_alignment_windows(lines, anchors, duration, coarse)
    indices = [index for index, window in enumerate(windows) if window is not None]
    if not indices:
        raise AlignmentFailure("逐字分析没有可靠的音频区间。")
    status("正在依据逐行时间点分析真实词级节奏…")
    def progress(current, total):
        if _number(current) and _number(total) and total > 0:
            status(f"正在分析词级节奏… {min(99, max(0, int(current / total * 100)))}%")
    # Stable-ts normalizes only whitespace and supplies Whisper's expected
    # leading-space token. Exact output text is restored by validated_words.
    result = model.align_words(audio, [windows[index] for index in indices],
                               language=request["language"], normalize_text=True,
                               inplace=False, regroup=False, verbose=None,
                               min_word_dur=0.02, progress_callback=progress)
    if result is None or len(result.segments) != len(indices):
        raise AlignmentFailure("逐字分析结果与歌词行数不一致。")
    output = [{"text": text, "start": supplied[index], "end": None, "words": []}
              for index, text in enumerate(lines)]
    for index, segment in zip(indices, result.segments):
        window = windows[index]
        if "".join(getattr(segment, "text", "").split()) != "".join(lines[index].split()):
            continue
        words = validated_words(lines[index], getattr(segment, "words", []),
                                window["start"], window["end"])
        if words:
            output[index] = {"text": lines[index], "start": window["start"],
                             "end": words[-1]["end"], "words": words}
    if not any(row["words"] for row in output):
        raise AlignmentFailure("没有得到可靠的词级时间点，保留原逐行歌词。")
    return output


def alignment_thread_count(request):
    if request.get("granularity") != "word":
        return max(1, min(4, os.cpu_count() or 1))
    try:
        return max(1, min(4, int(os.environ.get("MINIVOICE_ALIGNMENT_THREADS", "2"))))
    except (TypeError, ValueError):
        return 2


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
    model_name = request.get("model", "medium")
    if model_name not in ("small", "medium"):
        raise AlignmentFailure("不支持的歌词模型。")
    status(f"正在加载 Whisper {model_name}…")
    import stable_whisper
    import torch
    torch.set_num_threads(alignment_thread_count(request))
    model_path = Path(request["modelDirectory"]) / (model_name + ".pt")
    if not model_path.is_file():
        raise AlignmentFailure("应用缺少本地模型，请重新安装完整版本。")
    model = stable_whisper.load_model(str(model_path), device="cpu")
    status("正在分析歌曲并匹配歌词…")

    def progress(current, total):
        if total:
            status(f"正在匹配歌词… {min(99, int(current / total * 100))}%")

    if request.get("granularity") == "word":
        segments = align_word_rows(model, audio, request, status)
    else:
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
    # PyInstaller's frozen worker can be started by multiprocessing's resource
    # tracker. Handle those arguments before treating them as alignment inputs.
    import multiprocessing
    multiprocessing.freeze_support()
    if sys.argv[1] == "--capabilities":
        print(json.dumps({"protocolVersion": 1, "wordAlignment": 1, "anchoredWordAlignment": 1}))
        sys.exit(0)
    if sys.argv[1] == "--self-test":
        import stable_whisper
        import torch
        import whisper
        import tiktoken
        from whisper.tokenizer import get_tokenizer
        get_tokenizer(multilingual=True, language="zh", task="transcribe").encode("离线歌词")
        if len(sys.argv) > 2:
            torch.set_num_threads(2)
            model = stable_whisper.load_model(sys.argv[2], device="cpu")
            with torch.no_grad():
                model.encoder(torch.zeros(1, model.dims.n_mels, 3000))
            print("Offline model inference OK")
        print("Offline runtime OK", torch.__version__)
        sys.exit(0)
    if sys.argv[1] == "--download-model":
        import whisper
        name, directory = sys.argv[2:4]
        if name not in ("small", "medium"):
            raise ValueError("Unsupported model")
        progress_path = Path(sys.argv[4])
        def report(message):
            temporary = progress_path.with_suffix(".tmp")
            temporary.write_text(message, encoding="utf-8")
            os.replace(temporary, progress_path)
        original_progress = whisper.tqdm
        class DownloadProgress(original_progress):
            last_percent = -1
            def update(self, amount=1):
                result = super().update(amount)
                if self.total:
                    percent = int(self.n * 100 / self.total)
                    if percent != self.last_percent:
                        self.last_percent = percent
                        report(f"下载 {name}：{percent}% · {self.n / 1048576:.1f} / {self.total / 1048576:.1f} MB" if percent < 100 else "下载完成，正在校验模型…")
                return result
        whisper.tqdm = DownloadProgress
        report("正在连接下载服务器并检查本地模型…")
        whisper._download(whisper._MODELS[name], directory, in_memory=False)
        sys.exit(0)
    try:
        main()
    except Exception as error:
        traceback.print_exc()
        message = str(error) if isinstance(error, AlignmentFailure) else "本地 AI 未能完成同步。请稍后重试，或先保存歌词文本。"
        Path(sys.argv[2]).with_suffix(".error.json").write_text(json.dumps({"message": message}, ensure_ascii=False), encoding="utf-8")
        sys.exit(1)
