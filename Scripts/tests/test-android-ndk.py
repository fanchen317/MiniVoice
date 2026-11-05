#!/usr/bin/env python3
import os,pathlib,subprocess,tempfile,unittest
SOURCE=pathlib.Path(__file__).resolve().parents[1]/'common/android-sdk.sh'
class NDKDiscovery(unittest.TestCase):
    def test_split_roots_and_explicit_validation(self):
        with tempfile.TemporaryDirectory() as folder:
            root=pathlib.Path(folder);home=root/'home';sdk=root/'sdk'
            def fake(base,version='27.2.12479018'):
                base.mkdir(parents=True);(base/'source.properties').write_text('Pkg.Revision = '+version+'\n')
                tools=base/'toolchains/llvm/prebuilt/darwin-x86_64/bin';tools.mkdir(parents=True)
                for name in ['clang','clang++','llvm-strip']:
                    p=tools/name;p.write_text('#!/bin/sh\nexit 0\n');p.chmod(0o755)
                return base
            other=fake(home/'Android/Sdk/ndk/27.2.12479018')
            env={k:v for k,v in os.environ.items() if k!='ANDROID_NDK_HOME'};env['HOME']=str(home)
            def find(extra=None):return subprocess.run(['bash','-c','set -euo pipefail; source "$1"; repo_root="$2"; minivoice_find_ndk "$3"','test',str(SOURCE),str(root),str(sdk)],env={**env,**(extra or {})},text=True,capture_output=True)
            result=find();self.assertEqual(result.returncode,0,result.stderr);self.assertEqual(result.stdout.strip(),str(other))
            local=fake(sdk/'ndk/27.2.12479018');self.assertEqual(find().stdout.strip(),str(local))
            explicit=fake(root/'explicit');self.assertEqual(find({'ANDROID_NDK_HOME':str(explicit)}).stdout.strip(),str(explicit))
            wrong=fake(root/'wrong','28.0.0');self.assertNotEqual(find({'ANDROID_NDK_HOME':str(wrong)}).returncode,0)
            (explicit/'toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-strip').unlink();self.assertNotEqual(find({'ANDROID_NDK_HOME':str(explicit)}).returncode,0)
            self.assertNotEqual(find({'ANDROID_NDK_HOME':str(root/'missing')}).returncode,0)
if __name__=='__main__':unittest.main()
