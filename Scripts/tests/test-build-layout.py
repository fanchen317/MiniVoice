#!/usr/bin/env python3
import importlib.util,pathlib,tempfile,unittest,contextlib,io
script=pathlib.Path(__file__).resolve().parents[1]/'tools/migrate-build-layout.py'
spec=importlib.util.spec_from_file_location('layout',script);layout=importlib.util.module_from_spec(spec);spec.loader.exec_module(layout)
class Migration(unittest.TestCase):
    def test_preview_and_apply_preserve_packages_reports_and_collisions(self):
        with tempfile.TemporaryDirectory() as d,contextlib.redirect_stdout(io.StringIO()):
            root=pathlib.Path(d)
            for file,data in {'.build/Shared/Core/report.png':b'report','.build/Shared/Core/core.o':b'object','.build/MiniVoice.app/Contents/app':b'app','.build/Shared/UI/index.html':b'old','.build/work/shared-ui/index.html':b'new'}.items():
                p=root/file;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
            layout.migrate(root)
            self.assertTrue((root/'.build/MiniVoice.app/Contents/app').exists())
            layout.migrate(root,True)
            self.assertEqual((root/'.build/dist/MiniVoice.app/Contents/app').read_bytes(),b'app')
            self.assertEqual((root/'.build/reports/ui/report.png').read_bytes(),b'report')
            self.assertEqual((root/'.build/work/shared-core/core.o').read_bytes(),b'object')
            self.assertEqual((root/'.build/work/shared-ui/index.html').read_bytes(),b'new')
            self.assertEqual((root/'.build/archive/pre-migration/Shared/UI/index.html').read_bytes(),b'old')
            self.assertEqual(layout.migrate(root),[])
    def test_refuses_active_build(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d);(root/'.build/work/package-workflow.lock').mkdir(parents=True)
            with self.assertRaises(RuntimeError):layout.migrate(root,True)
if __name__=='__main__':unittest.main()
