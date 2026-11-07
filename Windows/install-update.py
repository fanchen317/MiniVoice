"""Transactional file update for the per-user Windows installer (stdlib only)."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import tempfile

MANIFEST = '.minivoice-install-files.json'
MODEL = 'resources/app.asar.unpacked/resources/LyricsAI/models/small.pt'


def digest(file):
    result = hashlib.sha256()
    with file.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def safe_path(root, name):
    parts = name.split('/')
    if not parts or '\\' in name or ':' in name or any(p in ('.', '..') for p in parts) or PurePosixPath(name).is_absolute():
        raise ValueError('安装文件清单包含无效路径')
    file = root.joinpath(*parts)
    if not file.resolve().is_relative_to(root.resolve()):
        raise ValueError('安装目录包含指向外部的链接')
    return file


def read_manifest(root, optional=False):
    file = root / MANIFEST
    if optional and not file.exists():
        return {}
    value = json.loads(file.read_text(encoding='utf-8'))
    if value.get('schema') != 1 or not isinstance(value.get('files'), dict):
        raise ValueError('安装文件清单无效')
    seen = set()
    for name, checksum in value['files'].items():
        safe_path(root, name)
        if name == MANIFEST or name.casefold() in seen or not isinstance(checksum, str) or len(checksum) != 64:
            raise ValueError('安装文件清单无效')
        seen.add(name.casefold())
    return value['files']


def check_available(file):
    if os.name != 'nt' or not file.exists():
        return
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.CreateFileW.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p]
    kernel.CreateFileW.restype = ctypes.c_void_p
    kernel.CloseHandle.argtypes = [ctypes.c_void_p]
    handle = kernel.CreateFileW(str(file), 0x40000000, 0, None, 3, 0x80, None)
    if handle == ctypes.c_void_p(-1).value:
        code = ctypes.get_last_error()
        if code in (32, 33):
            raise PermissionError('MiniVoice 或歌词匹配仍在运行，请从托盘退出应用后重试。')
        raise PermissionError('无法更新安装目录，请检查目录权限或文件占用。')
    kernel.CloseHandle(handle)


def atomic_copy(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix='.minivoice-copy-', dir=target.parent)
    os.close(descriptor)
    try:
        shutil.copy2(source, temporary)
        os.replace(temporary, target)
    finally:
        Path(temporary).unlink(missing_ok=True)


def stamp(file):
    info = file.stat()
    return info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns


def can_reuse_model(source, target):
    incoming = read_manifest(Path(source))
    expected = incoming.get(MODEL)
    existing = safe_path(Path(target), MODEL)
    if not expected or not existing.is_file():
        return False
    before = stamp(existing)
    return digest(existing) == expected and stamp(existing) == before


def install(source, target, backup, copy=atomic_copy):
    source, target, backup = map(lambda p: Path(p).absolute(), (source, target, backup))
    if source == target or source.is_relative_to(target) or target.is_relative_to(source):
        raise ValueError('安装源目录和目标目录不能重叠')
    incoming = read_manifest(source)
    previous = read_manifest(target, optional=True)
    if not incoming:
        raise ValueError('安装包没有应用文件')
    # Verify either the retained installed file or the incoming replacement.
    # Unchanged models can intentionally be absent from the extracted payload.
    unchanged = {}
    for name, expected in incoming.items():
        existing = safe_path(target, name)
        if existing.is_file():
            before = stamp(existing)
            if digest(existing) == expected and stamp(existing) == before:
                unchanged[name] = before
                continue
        if digest(safe_path(source, name)) != expected:
            raise ValueError('安装文件校验失败，请重新下载安装包。')
    names = sorted(set(incoming) | set(previous)) + [MANIFEST]
    for name in names:
        destination = safe_path(target, name)
        if destination.exists() and not destination.is_file():
            raise ValueError('安装目录中存在与应用文件冲突的目录')
        check_available(destination)
    if backup.is_relative_to(target) or target.is_relative_to(backup) or backup.is_relative_to(source) or source.is_relative_to(backup):
        raise ValueError('备份目录必须独立于应用目录')
    backup.mkdir(parents=True, exist_ok=True)
    if any(backup.iterdir()):
        raise ValueError('备份目录必须为空')
    changed = []
    try:
        for name in names:
            if name in unchanged:
                if stamp(safe_path(target, name)) != unchanged[name]:
                    raise OSError('已安装文件在校验后发生变化，请重试安装。')
                continue
            destination = safe_path(target, name)
            old = None
            if destination.exists():
                old = backup.joinpath(*PurePosixPath(name).parts)
                old.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(destination, old)
            changed.append((destination, old))
            if name in incoming or name == MANIFEST:
                copy(safe_path(source, name), destination)
                if name in incoming and digest(destination) != incoming[name]:
                    raise OSError('写入后的安装文件校验失败')
            else:
                destination.unlink(missing_ok=True)
    except Exception as error:
        failures = []
        for destination, old in reversed(changed):
            try:
                if old is None:
                    destination.unlink(missing_ok=True)
                else:
                    atomic_copy(old, destination)
            except OSError:
                failures.append(str(destination))
        if failures:
            raise RuntimeError('更新失败，部分文件未能恢复；请退出应用后重新运行安装包。备份位置：' + str(backup)) from error
        shutil.rmtree(backup)
        raise RuntimeError('更新失败，已恢复更新前的应用文件。' + str(error)) from error
    shutil.rmtree(backup)
    # Only remove empty former package directories, never unknown user files.
    for directory in sorted({safe_path(target, name).parent for name in previous}, key=lambda p: len(p.parts), reverse=True):
        while directory != target and directory.is_relative_to(target):
            try:
                directory.rmdir()
            except OSError:
                break
            directory = directory.parent


def main():
    parser = argparse.ArgumentParser()
    for option in ('source', 'target'):
        parser.add_argument('--' + option, required=True)
    for option in ('backup', 'status'):
        parser.add_argument('--' + option)
    parser.add_argument('--can-reuse-model', action='store_true')
    args = parser.parse_args()
    if args.can_reuse_model:
        try:
            return 0 if can_reuse_model(args.source, args.target) else 2
        except Exception:
            return 2
    if not args.backup or not args.status:
        parser.error('install requires --backup and --status')
    try:
        install(args.source, args.target, args.backup)
    except Exception as error:
        Path(args.status).write_text(str(error), encoding='utf-16')
        return 1
    Path(args.status).write_text('安装完成', encoding='utf-16')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
