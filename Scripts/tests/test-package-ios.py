#!/usr/bin/env python3
"""Test archive/export routing with a fake Xcode; does not claim real signing."""
import os, pathlib, plistlib, shutil, subprocess, tempfile, unittest
SOURCE=pathlib.Path(__file__).resolve().parents[1]/'build/package-ios.sh'
class IOSPackage(unittest.TestCase):
    def test_channels_and_signing_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=pathlib.Path(tmp); scripts=root/'Scripts/build';scripts.mkdir(parents=True)
            shutil.copyfile(SOURCE,scripts/'package-ios.sh')
            (root/'Scripts/checks').mkdir();(root/'Scripts/checks/check-ui-standards.mjs').write_text('')
            binary=root/'bin';binary.mkdir()
            fake=binary/'xcodebuild';fake.write_text('''#!/usr/bin/env python3
import os,sys,json,pathlib,zipfile
with open(os.environ['CALLS'],'a') as f:f.write(json.dumps(sys.argv[1:])+'\\n')
if '-exportPath' in sys.argv:
 p=pathlib.Path(sys.argv[sys.argv.index('-exportPath')+1]);p.mkdir(parents=True)
 with zipfile.ZipFile(p/'export.ipa','w') as z:z.writestr('Payload/Test.app/fixture','mock export')
''');fake.chmod(0o755)
            options=root/'Export Options.plist';options.write_bytes(plistlib.dumps({'method':'development'}))
            env={k:v for k,v in os.environ.items() if not k.startswith('MINIVOICE_IOS_')}
            env.update(PATH=str(binary)+':'+env['PATH'],CALLS=str(root/'calls'))
            failed=subprocess.run(['bash',str(scripts/'package-ios.sh'),'experience'],env=env,capture_output=True)
            self.assertNotEqual(failed.returncode,0);self.assertFalse((root/'calls').exists())
            env.update(MINIVOICE_IOS_TEAM='TEAM',MINIVOICE_IOS_EXPORT_OPTIONS=str(options),MINIVOICE_IOS_EXPERIENCE_TEAM='EXPTEAM')
            for channel,suffix,bundle,team in [('release','','com.xcosmos.MiniVoice.ios','TEAM'),('experience','-experience','com.xcosmos.MiniVoice.ios.experience','EXPTEAM')]:
                result=subprocess.run(['bash',str(scripts/'package-ios.sh'),channel],env=env,capture_output=True,text=True)
                self.assertEqual(result.returncode,0,result.stderr)
                self.assertTrue((root/f'.build/dist/MiniVoice-ios{suffix}.ipa').is_file())
                calls=(root/'calls').read_text();self.assertIn('PRODUCT_BUNDLE_IDENTIFIER='+bundle,calls);self.assertIn('DEVELOPMENT_TEAM='+team,calls)
                self.assertIn('/ios/'+channel+'/DerivedData',calls)
                self.assertFalse(list((root/'.build/work/ios').iterdir()))
if __name__=='__main__':unittest.main()
