#!/usr/bin/env python3
"""Exercise public command routing without installing over a user's Mac app."""
import os, pathlib, shutil, subprocess, tempfile, unittest
SCRIPTS=pathlib.Path(__file__).resolve().parents[1]
class Workflows(unittest.TestCase):
    def test_public_commands_and_failure_propagation(self):
        with tempfile.TemporaryDirectory() as folder:
            root=pathlib.Path(folder); scripts=root/'Scripts'
            for group in ['build','checks','tools']:(scripts/group).mkdir(parents=True)
            for name in ['build','build-experience','deploy','deploy-experience']:
                shutil.copyfile(SCRIPTS/(name+'.sh'),scripts/(name+'.sh'))
            shutil.copyfile(SCRIPTS/'build/package-all.sh',scripts/'build/package-all.sh')
            (scripts/'checks/check-ui-standards.mjs').write_text('')
            (scripts/'tools/archive-legacy-packages.py').write_text('')
            for name in ['package-mac','build-android','package-ios']:
                (scripts/'build'/(name+'.sh')).write_text('printf "%s %s\\n" "'+name+'" "$*" >> "$(dirname "$0")/../../calls"\n[[ "${FAIL_PLATFORM:-}" != "'+name+'" ]]\n')
            for entry,action,variant in [('build','build','release'),('build-experience','build','experience'),('deploy','deploy','release'),('deploy-experience','deploy','experience')]:
                result=subprocess.run(['bash',str(scripts/(entry+'.sh')),'--no-launch'],capture_output=True,text=True)
                self.assertEqual(result.returncode,0,result.stderr)
                calls=(root/'calls').read_text().splitlines(); (root/'calls').unlink()
                self.assertEqual(calls,[f'package-mac {action} {variant} false',f'build-android {variant}',f'package-ios {variant}'])
                self.assertFalse((root/'.build/work/package-workflow.lock').exists())
            result=subprocess.run(['bash',str(scripts/'deploy.sh')],env={**os.environ,'FAIL_PLATFORM':'package-mac'},capture_output=True)
            self.assertNotEqual(result.returncode,0)
            self.assertIn('package-ios release',(root/'calls').read_text())
            result=subprocess.run(['bash',str(scripts/'build.sh'),'--platforms','android,unknown'],capture_output=True)
            self.assertEqual(result.returncode,2)
if __name__=='__main__': unittest.main()
