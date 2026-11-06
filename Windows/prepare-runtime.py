#!/usr/bin/env python3
"""Assemble a real Windows x64 offline runtime on macOS; never execute PE files here."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / '.build/cache/windows-downloads'
TARGET = ROOT / '.build/cache/windows-x64-resources'
MODEL_SHA = '9ecf779972d90ba49c06d968637d720dd632c55bbf19d441fb42bf17a411e794'

def sha(file):
    digest = hashlib.sha256()
    with open(file, 'rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()

def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)

def download(url, target, expected=None):
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.is_file() and expected and sha(target) == expected:
        return target
    pending = target.with_name(target.name + '.partial')
    # Resume only staging data. A failed transfer can never become a final resource.
    run('curl', '--fail', '--location', '--show-error', '--silent',
        '--connect-timeout', '20', '--speed-limit', '1024', '--speed-time', '60',
        '--retry', '5', '--retry-all-errors', '--continue-at', '-',
        '--output', pending, url)
    if expected and sha(pending) != expected:
        pending.unlink()
        raise RuntimeError(f'SHA256 校验失败：{target.name}')
    pending.replace(target)
    return target

def extract_zip(archive, target):
    with zipfile.ZipFile(archive) as source:
        for name in source.namelist():
            if not (target / name).resolve().is_relative_to(target.resolve()):
                raise RuntimeError('不安全的压缩包路径')
        source.extractall(target)

def prune_inference_files(site):
    site = Path(site)
    if site.name != 'site-packages' or not site.is_dir():
        raise RuntimeError('只能清理暂存运行时的 site-packages')
    # The bundled worker performs inference; it never builds C++ extensions.
    # Retain DLLs, PYDs, model data and licenses; omit static libraries and SDKs.
    for file in site.rglob('*'):
        if file.is_file() and file.suffix.lower() in ('.pdb', '.lib', '.a'):
            file.unlink()
    shutil.rmtree(site / 'torch/include', ignore_errors=True)

def main():
    for tool in ('x86_64-w64-mingw32-g++', 'x86_64-w64-mingw32-gcc', 'makensis'):
        if not shutil.which(tool):
            raise SystemExit(f'缺少 {tool}；macOS 先执行 brew install mingw-w64 nsis')
    CACHE.mkdir(parents=True, exist_ok=True)
    TARGET.mkdir(parents=True, exist_ok=True)
    python_archive = CACHE / 'python-3.11.9-embed-amd64.zip'
    download('https://www.python.org/ftp/python/3.11.9/' + python_archive.name, python_archive,
             '009d6bf7e3b2ddca3d784fa09f90fe54336d5b60f0e0f305c37f400bf83cfd3b')
    ai = TARGET / 'LyricsAI'
    ai.mkdir(exist_ok=True)
    extract_zip(python_archive, ai)
    site = ai / 'Lib/site-packages'
    site.mkdir(parents=True, exist_ok=True)
    (ai / 'python311._pth').write_text('python311.zip\n.\nLib/site-packages\nimport site\n')
    bootstrap = ROOT / '.build/cache/windows-bootstrap'
    if not bootstrap.exists():
        run(sys.executable, '-m', 'venv', bootstrap)
    pip = bootstrap / 'bin/pip'
    wheels = CACHE / 'wheels'
    locked = json.loads((ROOT / 'Windows/runtime-wheels.lock.json').read_text())
    if not all((wheels / item['filename']).is_file() and sha(wheels / item['filename']) == item['sha256'] for item in locked):
        run(pip, 'download', '--timeout', '30', '--retries', '3', '--dest', wheels,
            '--find-links', wheels, '--platform', 'win_amd64', '--python-version', '311',
            '--implementation', 'cp', '--abi', 'cp311', '--only-binary=:all:',
            '--require-hashes', '-r', ROOT / 'Windows/runtime-requirements.txt')
    for item in locked:
        if sha(wheels / item['filename']) != item['sha256']:
            raise RuntimeError(f"Windows wheel SHA256 不一致：{item['filename']}")
    builder = bootstrap / 'bin/python'
    ready = subprocess.run([str(builder), '-c', "from importlib.metadata import version; assert version('setuptools') == '84.2.1' and version('wheel') == '0.48.0'"], capture_output=True).returncode == 0
    if not ready:
        run(pip, 'install', 'setuptools==84.2.1', 'wheel==0.48.0')
    sources = [
        ('stable_ts-2.19.1.tar.gz', '94/d9/d326f9dbbb7da6806aa8cfc080342e5f78dc33552f4339bdc8a6251d11a3', '0ecaf1ed93e029839569618d2da9a57b883ad04db21f0680146e0650caaf4f52'),
        ('openai_whisper-20250625.tar.gz', '35/8e/d36f8880bcf18ec026a55807d02fe4c7357da9f25aebd92f85178000c0dc', '37a91a3921809d9f44748ffc73c0a55c9f366c85a3ef5c2ae0cc09540432eb96'),
    ]
    for name, remote, digest in sources:
        archive = download(f'https://files.pythonhosted.org/packages/{remote}/{name}', CACHE / 'sources' / name, digest)
        run(pip, 'wheel', '--no-deps', '--no-build-isolation', '--wheel-dir', wheels, archive)
    runtime_wheels = [wheels / item['filename'] for item in locked] + [wheels / 'stable_ts-2.19.1-py3-none-any.whl', wheels / 'openai_whisper-20250625-py3-none-any.whl']
    for archive in runtime_wheels:
        if not ('win_amd64' in archive.name or '-none-any.whl' in archive.name):
            raise RuntimeError(f'非Windows wheel：{archive.name}')
        extract_zip(archive, site)
        # Wheel .data/purelib and platlib must be installed at site-packages root.
        with zipfile.ZipFile(archive) as package:
            for name in package.namelist():
                parts = name.split('/')
                if len(parts) > 2 and parts[0].endswith('.data') and parts[1] in ('purelib', 'platlib') and not name.endswith('/'):
                    destination = site.joinpath(*parts[2:]); destination.parent.mkdir(parents=True, exist_ok=True)
                    destination.write_bytes(package.read(name))
    prune_inference_files(site)
    # msvc-runtime stores app-local DLLs in wheel .data/data (Python's prefix).
    for data in site.glob('msvc_runtime-*.data/data'):
        for file in data.rglob('*'):
            if file.is_file():
                destination = ai / file.name if file.suffix.lower() == '.dll' else ai / file.relative_to(data)
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(file, destination)
    licenses = ai / 'LICENSES'
    licenses.mkdir(exist_ok=True)
    shutil.copy2(ai / 'LICENSE.txt', licenses / 'Python-LICENSE.txt')
    for file in site.rglob('*'):
        if file.is_file() and any(token in file.name.lower() for token in ('license', 'copying', 'notice')):
            destination = licenses / file.relative_to(site)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(file, destination)
    shutil.copytree(ROOT / 'MacOS/Vendor/LyricsAI/licenses', licenses / 'model-and-worker', dirs_exist_ok=True)
    model = ROOT / 'MacOS/Vendor/LyricsAI/arm64/small.pt'
    if sha(model) != MODEL_SHA:
        raise RuntimeError('small.pt 模型 SHA256 不一致')
    (ai / 'models').mkdir(exist_ok=True)
    shutil.copy2(model, ai / 'models/small.pt')
    ffmpeg_name = 'ffmpeg-8.1.2-essentials_build.zip'
    base = 'https://github.com/GyanD/codexffmpeg/releases/download/8.1.2/'
    media = download(base + ffmpeg_name, CACHE / ffmpeg_name,
                     'db580001caa24ac104c8cb856cd113a87b0a443f7bdf47d8c12b1d740584a2ec')
    with zipfile.ZipFile(media) as package:
        for output, suffix in [('ffmpeg.exe', '/bin/ffmpeg.exe'), ('ffprobe.exe', '/bin/ffprobe.exe'), ('LICENSE.txt', '/LICENSE'), ('FFmpeg-README.txt', '/README.txt')]:
            names = [name for name in package.namelist() if name.endswith(suffix)]
            if len(names) != 1:
                raise RuntimeError(f'FFmpeg 资源缺失：{output}')
            (TARGET / output).write_bytes(package.read(names[0]))
    electron_version = json.loads((ROOT / 'Windows/package.json').read_text())['devDependencies']['electron']
    if electron_version != '44.10.2':
        raise RuntimeError('Electron 版本变化：先更新并验证 Windows 归档 SHA256')
    download('https://github.com/electron/electron/releases/download/v44.10.2/electron-v44.10.2-win32-x64.zip',
             CACHE / 'electron-v44.10.2-win32-x64.zip',
             '7af18e85a1537b832924ae3b0e5146602f2f4f4b0c77c74e4ae0dc251ca338f9')
    # Static Windows CRT/C++ linkage avoids missing mingw DLLs on users' machines.
    core = ROOT / 'Shared/Core'
    obj = CACHE / 'utf8proc-win64.o'
    run('x86_64-w64-mingw32-gcc', '-O2', '-DUTF8PROC_STATIC', '-c', core / 'Sources/MiniVoiceCore/vendor/utf8proc.c', '-o', obj)
    run('x86_64-w64-mingw32-g++', '-std=c++17', '-O2', '-s', '-static', '-DUTF8PROC_STATIC', '-I' + str(core / 'Sources/MiniVoiceCore'), core / 'Tests/cli.cpp', core / 'Sources/MiniVoiceCore/core.cpp', obj, '-o', TARGET / 'minivoice-core.exe')
    manifest = {'platform': 'win32-x64', 'python': '3.11.9', 'windowsRuntimeTested': False,
                'archives': {str(p.relative_to(CACHE)): sha(p) for p in [python_archive, media, *wheels.glob('*.whl'), * (CACHE / 'sources').glob('*.tar.gz')]},
                'files': {str(p.relative_to(TARGET)): sha(p) for p in sorted(TARGET.rglob('*')) if p.is_file() and p.name != 'resource-manifest.json'}}
    (TARGET / 'resource-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    run('node', ROOT / 'Windows/prepare-cross-resources.mjs', TARGET)
    print(f'Windows x64 资源就绪：{TARGET}', flush=True)

if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--prune-ai':
        prune_inference_files(Path(sys.argv[2]) / 'Lib/site-packages')
    else:
        main()
