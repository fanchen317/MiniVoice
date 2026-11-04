#!/usr/bin/env python3
"""Release metadata must fail closed when a platform drifts or a legacy route returns."""
import pathlib, shutil, subprocess, tempfile, unittest
ROOT=pathlib.Path(__file__).resolve().parents[2]
FILES=['Scripts/checks/check-release-config.mjs','Shared/version.json','MacOS/AppBundle/Info.plist','MacOS/Desktop/package.json','MacOS/Desktop/package-lock.json','Android/app/src/main/AndroidManifest.xml','Android/app/build.gradle','iOS/MiniVoice.xcodeproj/project.pbxproj','Android/app/src/main/java/com/xcosmos/minivoice/Diagnostics.java','Scripts/build/build-android.sh','MacOS/Sources/MiniVoice/DesktopEngine.swift']
class ReleaseConfig(unittest.TestCase):
    def test_consistency_and_regression_rejection(self):
        with tempfile.TemporaryDirectory() as folder:
            root=pathlib.Path(folder)
            for name in FILES:
                target=root/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,target)
            def check():return subprocess.run(['node',str(root/FILES[0])],capture_output=True).returncode
            self.assertEqual(check(),0)
            for name,old,new in [('Android/app/build.gradle',"versionName '3.0.0'","versionName '2.7.0'"),('iOS/MiniVoice.xcodeproj/project.pbxproj','MARKETING_VERSION = 3.0.0;','MARKETING_VERSION = 2.7.0;'),('MacOS/Sources/MiniVoice/DesktopEngine.swift','case "openSettings":','case "openSettings":\n panels.showSettings()')]:
                target=root/name;original=target.read_text();self.assertIn(old,original);target.write_text(original.replace(old,new));self.assertNotEqual(check(),0,name);target.write_text(original)
if __name__=='__main__':unittest.main()
