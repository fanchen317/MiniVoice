"""Local forced alignment worker. Only model weights are downloaded; audio stays local."""
import json
import math
import os
from pathlib import Path
import sys


def validated_segments(lines, segments, duration):
    if len(lines) != len(segments):
        raise ValueError("无法完整匹配每一行歌词，请检查歌词是否与当前歌曲版本一致。")
    output = []
    previous = -1.0
    for line, segment in zip(lines, segments):
        start, end = float(segment.start), float(segment.end)
        # Reject missing/collapsed/out-of-order alignment instead of inventing timestamps.
        if (not math.isfinite(start) or not math.isfinite(end) or
                start < 0 or start <= previous or end <= start or end > duration + 0.5):
            raise ValueError("部分歌词未能可靠匹配，请检查漏句、重复段落或使用手动打点。")
        compact = lambda value: "".join(value.split())
        if compact(segment.text) != compact(line):
            raise ValueError("对齐结果与原歌词不一致，已保留原文。")
        output.append({"text": line, "start": start, "end": end})
        previous = start
    return output


def main():
    request_path, output_path, status_path = map(Path, sys.argv[1:4])
    request = json.loads(request_path.read_text(encoding="utf-8"))

    def status(message):
        temporary = status_path.with_suffix(".tmp")
        temporary.write_text(message, encoding="utf-8")
        os.replace(temporary, status_path)

    status("正在加载 AI 模型（首次使用需要下载约 460 MB）…")
    import stable_whisper
    import torch
    torch.set_num_threads(max(1, min(4, os.cpu_count() or 1)))
    model = stable_whisper.load_model("small", device="cpu", download_root=request["modelDirectory"])
    status("正在分析歌曲并匹配歌词…")

    def progress(current, total):
        if total:
            status(f"正在匹配歌词… {min(99, int(current / total * 100))}%")

    result = model.align(
        request["audioPath"], "\n".join(request["lines"]), language=request["language"],
        original_split=True, regroup=False, verbose=False, progress_callback=progress,
    )
    if result is None:
        raise ValueError("未找到可用的歌词时间轴。")
    segments = validated_segments(request["lines"], result.segments, request["duration"])
    output_path.write_text(json.dumps(segments, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
