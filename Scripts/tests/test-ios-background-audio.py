#!/usr/bin/env python3
"""Check the source and packaged iOS background-audio capability, without launching an app."""
import pathlib
import plistlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]


def check(path):
    with path.open("rb") as stream:
        info = plistlib.load(stream)
    modes = info.get("UIBackgroundModes", [])
    if not isinstance(modes, list) or "audio" not in modes:
        raise ValueError(f"{path}: UIBackgroundModes 缺少 audio，切后台后系统可挂起播放")
    print(f"PASS iOS background audio capability: {path}")


if __name__ == "__main__":
    paths = [ROOT / "iOS/MiniVoice/Info.plist", *map(pathlib.Path, sys.argv[1:])]
    try:
        for path in paths:
            check(path)
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        print(f"FAIL {error}", file=sys.stderr)
        sys.exit(1)
