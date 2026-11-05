#!/usr/bin/env python3
"""Public build/install contract, isolated from real toolchains and Applications."""
import os,pathlib,shutil,subprocess,tempfile,unittest
SCRIPTS=pathlib.Path(__file__).resolve().parents[1]
class Workflows(unittest.TestCase):
 def test_versioned_build_failure_and_install_only(self):
  with tempfile.TemporaryDirectory() as folder:
   root=pathlib.Path(folder)
   for group in ['build','checks','common']:(root/'Scripts'/group).mkdir(parents=True)
   (root/'Shared').mkdir();(root/'Shared/version.json').write_text('{"version":"3.0.0","build":30000}')
   for name in ['build.sh','deploy.sh','build/package-all.sh','common/release-output.sh']:shutil.copyfile(SCRIPTS/name,root/'Scripts'/name)
   (root/'Scripts/checks/check-ui-standards.mjs').write_text('')
   stubs={'package-mac':'mkdir -p "$dist/MiniVoice-3.0.0-mac.app"; touch "$dist/MiniVoice-3.0.0-mac.dmg"','build-android':'touch "$dist/MiniVoice-3.0.0-android.apk"','package-windows':'touch "$dist/MiniVoice-3.0.0-windows-x64-setup.exe"'}
   for name,output in stubs.items():
    (root/f'Scripts/build/{name}.sh').write_text('set -eu\nroot="$(cd "$(dirname "$0")/../.." && pwd)"\necho '+name+' >> "$root/calls"\n[[ "${FAIL_PLATFORM:-}" != "'+name+'" ]] || exit 1\ndist="$root/.build/dist"\nmkdir -p "$dist"\n'+output+'\n')
   def run(*args,env=None):return subprocess.run(['bash',str(root/'Scripts/build.sh'),*args],capture_output=True,text=True,errors="replace",env=env)
   result=run('--platforms','mac,android,windows');self.assertEqual(result.returncode,0,result.stderr);self.assertIn('windows：成功',result.stdout)
   result=run('--platforms','mac,android',env={**os.environ,'FAIL_PLATFORM':'package-mac'});self.assertNotEqual(result.returncode,0);self.assertIn('android：成功',result.stdout);self.assertFalse((root/'.build/work/package-workflow.lock').exists())
   self.assertEqual(run('--platforms','ios').returncode,2)
   self.assertEqual(run('--platforms','unknown').returncode,2)
   bindir=root/'bin';bindir.mkdir();(bindir/'uname').write_text('#!/bin/sh\necho Darwin\n');(bindir/'uname').chmod(0o755)
   (root/'Scripts/build/install-mac.sh').write_text('printf "%s\\n" "$*" > "$(dirname "$0")/../../install-call"\n')
   before=(root/'calls').read_text();result=subprocess.run(['bash',str(root/'Scripts/deploy.sh'),'--no-launch'],capture_output=True,text=True,errors="replace",env={**os.environ,'PATH':str(bindir)+os.pathsep+os.environ['PATH']})
   self.assertEqual(result.returncode,0,result.stderr);self.assertEqual((root/'calls').read_text(),before);self.assertEqual((root/'install-call').read_text().strip(),'--skip-build --no-launch')
if __name__=='__main__':unittest.main()
