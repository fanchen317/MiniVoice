import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('update', Path(__file__).resolve().parents[2] / 'Windows/install-update.py')
update = importlib.util.module_from_spec(spec)
spec.loader.exec_module(update)


def payload(root, files):
    root.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for name, content in files.items():
        file = root / name
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_bytes(content)
        manifest[name] = hashlib.sha256(content).hexdigest()
    (root / update.MANIFEST).write_text(json.dumps({'schema': 1, 'files': manifest}))


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source, self.target, self.backup = [self.root / p for p in ('incoming', 'installed', 'backup')]

    def test_upgrade_removes_only_old_owned_files_and_preserves_unknown_files(self):
        payload(self.target, {'MiniVoice.exe': b'old', 'resources/obsolete.dll': b'old dependency'})
        (self.target / 'my-music.mp3').write_bytes(b'user music')
        payload(self.source, {'MiniVoice.exe': b'new', 'resources/new.dll': b'new dependency'})
        update.install(self.source, self.target, self.backup)
        self.assertEqual((self.target / 'MiniVoice.exe').read_bytes(), b'new')
        self.assertFalse((self.target / 'resources/obsolete.dll').exists())
        self.assertEqual((self.target / 'my-music.mp3').read_bytes(), b'user music')
        self.assertEqual(update.read_manifest(self.target), update.read_manifest(self.source))
        self.assertFalse(self.backup.exists())

    def test_failed_copy_restores_old_version_and_manifest(self):
        payload(self.target, {'a.exe': b'old executable', 'z.dll': b'old dependency'})
        old_manifest = (self.target / update.MANIFEST).read_bytes()
        payload(self.source, {'a.exe': b'new executable', 'b.dll': b'new dependency'})
        def fail(source, target):
            if target.name == 'b.dll':
                raise OSError('synthetic disk failure')
            update.atomic_copy(source, target)
        with self.assertRaisesRegex(RuntimeError, '已恢复'):
            update.install(self.source, self.target, self.backup, copy=fail)
        self.assertEqual((self.target / 'a.exe').read_bytes(), b'old executable')
        self.assertEqual((self.target / 'z.dll').read_bytes(), b'old dependency')
        self.assertFalse((self.target / 'b.dll').exists())
        self.assertEqual((self.target / update.MANIFEST).read_bytes(), old_manifest)

    def test_corrupt_payload_does_not_touch_existing_installation(self):
        payload(self.target, {'a.exe': b'old'})
        payload(self.source, {'a.exe': b'new'})
        (self.source / 'a.exe').write_bytes(b'corrupt')
        with self.assertRaisesRegex(ValueError, '校验失败'):
            update.install(self.source, self.target, self.backup)
        self.assertEqual((self.target / 'a.exe').read_bytes(), b'old')
        self.assertFalse(self.backup.exists())

    def test_running_app_is_detected_before_any_write(self):
        payload(self.target, {'a.exe': b'old'})
        payload(self.source, {'a.exe': b'new'})
        with patch.object(update, 'check_available', side_effect=PermissionError('running app')):
            with self.assertRaises(PermissionError):
                update.install(self.source, self.target, self.backup)
        self.assertEqual((self.target / 'a.exe').read_bytes(), b'old')
        self.assertFalse(self.backup.exists())

    def test_legacy_install_without_manifest_keeps_unknown_old_files(self):
        self.target.mkdir()
        (self.target / 'unknown.txt').write_bytes(b'preserve')
        payload(self.source, {'MiniVoice.exe': b'new'})
        update.install(self.source, self.target, self.backup)
        self.assertEqual((self.target / 'unknown.txt').read_bytes(), b'preserve')

    def test_traversal_and_external_links_cannot_touch_outside_installation(self):
        payload(self.source, {'a.exe': b'new'})
        self.target.mkdir()
        outside = self.root / 'outside'
        outside.mkdir()
        (self.target / 'linked').symlink_to(outside, target_is_directory=True)
        for name in ('../outside/a.exe', '/absolute.exe', 'C:/Windows/a.exe', 'linked/a.exe', 'foo/./a.exe', 'foo\\a.exe'):
            with self.subTest(name=name), self.assertRaises(ValueError):
                update.safe_path(self.target, name)

    def test_matching_model_skips_missing_staged_model_and_all_model_writes(self):
        payload(self.target, {update.MODEL: b'unchanged offline model', 'MiniVoice.exe': b'old'})
        payload(self.source, {update.MODEL: b'unchanged offline model', 'MiniVoice.exe': b'new'})
        self.assertTrue(update.can_reuse_model(self.source, self.target))
        model = self.target / update.MODEL
        old_stamp = update.stamp(model)
        (self.source / update.MODEL).unlink()  # NSIS intentionally skipped extraction.
        copied = []
        def copy(source, target):
            copied.append(str(target.relative_to(self.target)))
            update.atomic_copy(source, target)
        update.install(self.source, self.target, self.backup, copy=copy)
        self.assertEqual(update.stamp(model), old_stamp)
        self.assertNotIn(update.MODEL, copied)
        self.assertEqual((self.target / 'MiniVoice.exe').read_bytes(), b'new')

    def test_changed_or_missing_model_requires_the_new_payload(self):
        payload(self.source, {update.MODEL: b'new offline model'})
        self.assertFalse(update.can_reuse_model(self.source, self.target))
        payload(self.target, {update.MODEL: b'old offline model'})
        self.assertFalse(update.can_reuse_model(self.source, self.target))
        update.install(self.source, self.target, self.backup)
        self.assertEqual((self.target / update.MODEL).read_bytes(), b'new offline model')

    def test_missing_skipped_model_is_not_silently_accepted(self):
        payload(self.target, {update.MODEL: b'changed since reuse check', 'MiniVoice.exe': b'old'})
        payload(self.source, {update.MODEL: b'correct model', 'MiniVoice.exe': b'new'})
        (self.source / update.MODEL).unlink()
        with self.assertRaises(FileNotFoundError):
            update.install(self.source, self.target, self.backup)
        self.assertEqual((self.target / 'MiniVoice.exe').read_bytes(), b'old')

    def test_identical_runtime_files_are_not_backed_up_or_replaced(self):
        payload(self.source, {'runtime.dll': b'unchanged', 'MiniVoice.exe': b'new'})
        payload(self.target, {'runtime.dll': b'unchanged', 'MiniVoice.exe': b'old'})
        touched = []
        def copy(source, target):
            touched.append(target.name)
            update.atomic_copy(source, target)
        update.install(self.source, self.target, self.backup, copy=copy)
        self.assertNotIn('runtime.dll', touched)

    def test_nonempty_backup_is_never_overwritten(self):
        payload(self.source, {'a.exe': b'new'})
        self.backup.mkdir()
        (self.backup / 'user-file').write_bytes(b'preserve')
        with self.assertRaisesRegex(ValueError, '必须为空'):
            update.install(self.source, self.target, self.backup)
        self.assertEqual((self.backup / 'user-file').read_bytes(), b'preserve')


if __name__ == '__main__':
    unittest.main()
