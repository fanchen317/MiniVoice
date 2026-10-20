# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller recipe for the pinned stable-ts worker (macOS arm64)."""
from pathlib import Path
from PyInstaller.utils.hooks import collect_all, collect_submodules

root = Path.cwd()
datas = []
binaries = []
hiddenimports = collect_submodules("tiktoken_ext")
for module in ("stable_whisper", "whisper", "tiktoken"):
    module_data, module_binaries, module_imports = collect_all(module)
    datas += module_data
    binaries += module_binaries
    hiddenimports += module_imports

analysis = Analysis(
    [str(root / "MacOS/Sources/MiniVoice/Resources/align_lyrics.py")],
    pathex=[str(root)],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
archive = PYZ(analysis.pure)
executable = EXE(
    archive,
    analysis.scripts,
    [],
    exclude_binaries=True,
    name="lyrics-worker",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch="arm64",
    codesign_identity=None,
    entitlements_file=None,
)
bundle = COLLECT(
    executable,
    analysis.binaries,
    analysis.datas,
    strip=True,
    upx=False,
    name="lyrics-worker",
)
