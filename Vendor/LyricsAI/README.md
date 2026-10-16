# Bundled lyrics AI (macOS arm64)

The default installation includes the original OpenAI Whisper **small** multilingual checkpoint and a self-contained PyInstaller worker built from `Sources/MiniVoice/Resources/align_lyrics.py`. Both assets are pinned in `arm64/SHA256SUMS` and stored with Git LFS. `Scripts/build-app.sh`, `Scripts/deploy.sh`, and `Scripts/build-dmg.sh` read only these checked-in assets; they do not download the runtime or small model.

- `arm64/small.pt`: OpenAI Whisper small checkpoint, SHA-256 `9ecf779972d90ba49c06d968637d720dd632c55bbf19d441fb42bf17a411e794`. Source: [OpenAI Whisper model registry](https://github.com/openai/whisper/blob/main/whisper/__init__.py).
- `arm64/lyrics-worker.tar.gz`: current MiniVoice alignment code bundled with stable-ts 2.19.1, PyTorch 2.8.0, torchaudio 2.8.0, openai-whisper 20250625, and PyInstaller 6.16.0. The archive is about 113 MiB and unpacks to about 338 MiB. FFmpeg is supplied separately from `Vendor/FFmpeg`; it is not duplicated in this worker.

The `licenses/` folder contains licenses for the principal bundled components. Python distribution metadata and additional notices are retained in the worker archive where supplied by the packages. Before publishing a DMG, review the full set of third-party distribution obligations.

To recreate or update the checked-in worker and model from an already installed local Python environment, run `Scripts/refresh-lyrics-assets.sh /absolute/path/to/small.pt`. This is an explicit maintenance operation; routine app and DMG builds never invoke it. The script verifies the original model hash, rebuilds the worker from current source, strips only debug symbols from the two largest libraries, runs the real model self-test, and updates the archive checksums. After updating assets, commit the Git LFS pointers and ensure the LFS objects are available to anyone building from the repository.

The medium model remains optional and is downloaded on demand if selected. Intel Mac builds need separately built and verified x86_64 assets.
