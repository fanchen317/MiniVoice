#!/usr/bin/env python3
"""Exercise public command routing without installing over a user's Mac app."""
import pathlib, shutil, subprocess, tempfile, unittest
ROOT = pathlib.Path(__file__).resolve().parent
class Workflows(unittest.TestCase):
    def test_public_commands_and_failure_propagation(self):
        with tempfile.TemporaryDirectory() as folder:
            root=pathlib.Path(folder); scripts=root/'Scripts'; scripts.mkdir()
            for name in ['build','build-experience','deploy','deploy-experience','package-all']:
                shutil.copyfile(ROOT/(name+'.sh'),scripts/(name+'.sh'))
            (scripts/'check-ui-standards.mjs').write_text('')
            (scripts/'archive-legacy-packages.py').write_text('')
            for name in ['package-mac','build-android','package-ios']:
                (scripts/(name+'.sh')).write_text('printf "%s %s\\n" "'+name+'" "$*" >> "$(dirname "$0")/../calls"\n[[ "${FAIL_PLATFORM:-}" != "'+name+'" ]]\n')
            for entry,action,variant in [('build','build','release'),('build-experience','build','experience'),('deploy','deploy','release'),('deploy-experience','deploy','experience')]:
                result=subprocess.run(['bash',str(scripts/(entry+'.sh')),'--no-launch'],capture_output=True,text=True)
                self.assertEqual(result.returncode,0,result.stderr)
                calls=(root/'calls').read_text().splitlines(); (root/'calls').unlink()
                self.assertEqual(calls,[f'package-mac {action} {variant} false',f'build-android {variant}',f'package-ios {variant}'])
                self.assertFalse((root/'.build/package-workflow.lock').exists())
            import os
            result=subprocess.run(['bash',str(scripts/'deploy.sh')],env={**os.environ,'FAIL_PLATFORM':'package-mac'},capture_output=True)
            self.assertNotEqual(result.returncode,0)
            self.assertIn('package-ios release',(root/'calls').read_text())
            result=subprocess.run(['bash',str(scripts/'build.sh'),'--platforms','android,unknown'],capture_output=True)
            self.assertEqual(result.returncode,2)
if __name__=='__main__': unittest.main()
