import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location('windows_runtime', Path(__file__).resolve().parents[2] / 'Windows/prepare-runtime.py')
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)

class RuntimeResourceTests(unittest.TestCase):
    def test_bad_hash_never_publishes_or_overwrites_final_resource(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'model.pt'
            target.write_bytes(b'previous resource')
            def transfer(*args):
                target.with_name(target.name + '.partial').write_bytes(b'incomplete download')
            with patch.object(runtime, 'run', transfer):
                with self.assertRaisesRegex(RuntimeError, 'SHA256'):
                    runtime.download('https://example.invalid/resource', target, '0' * 64)
            self.assertEqual(target.read_bytes(), b'previous resource')
            self.assertFalse(target.with_name(target.name + '.partial').exists())

    def test_verified_cached_file_needs_no_network(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'file'
            target.write_bytes(b'verified')
            with patch.object(runtime, 'run', side_effect=AssertionError('network forbidden')):
                self.assertEqual(runtime.download('https://example.invalid', target, runtime.sha(target)), target)

    def test_pruning_retains_inference_binaries_models_and_licenses(self):
        with tempfile.TemporaryDirectory() as directory:
            site = Path(directory) / 'site-packages'
            site.mkdir()
            for name in ['torch_cpu.dll', 'binding.pyd', 'model.pt', 'LICENSE', 'development.lib', 'debug.PDB']:
                (site / name).write_bytes(b'synthetic')
            (site / 'torch/include').mkdir(parents=True)
            (site / 'torch/include/sdk.h').write_bytes(b'synthetic')
            runtime.prune_inference_files(site)
            self.assertFalse((site / 'development.lib').exists())
            self.assertFalse((site / 'debug.PDB').exists())
            self.assertFalse((site / 'torch/include').exists())
            for name in ['torch_cpu.dll', 'binding.pyd', 'model.pt', 'LICENSE']:
                self.assertTrue((site / name).exists())

    def test_zip_cannot_escape_destination(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / 'bad.zip'
            with zipfile.ZipFile(archive, 'w') as package:
                package.writestr('../escape.exe', b'bad')
            with self.assertRaisesRegex(RuntimeError, '压缩包'):
                runtime.extract_zip(archive, Path(directory) / 'runtime')
            self.assertFalse((Path(directory) / 'escape.exe').exists())

if __name__ == '__main__':
    unittest.main()
