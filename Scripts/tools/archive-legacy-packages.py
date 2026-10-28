#!/usr/bin/env python3
"""Move previous ad-hoc outputs out of public package directories, preserving them."""
from pathlib import Path
from datetime import datetime
import shutil
root=Path(__file__).resolve().parent.parent.parent/'.build'
canonical={'MiniVoice-android.apk','MiniVoice-android-experience.apk','MiniVoice-mac.dmg','MiniVoice-mac-experience.dmg','MiniVoice-ios.ipa'}
archive=root/'archive'/'installers'/datetime.now().strftime('%Y%m%d-%H%M%S-%f')
for directory in (root/'work/android',root/'dist'):
    if not directory.exists(): continue
    for file in directory.iterdir():
        if file.is_symlink() or not file.is_file(): continue
        if directory.name=='dist' and file.name in canonical: continue
        if not file.name.startswith('MiniVoice-') or not file.name.endswith(('.apk','.apk.idsig','.dmg','.ipa')): continue
        target=archive/directory.name/file.name
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.move(str(file),str(target))
        print(f'历史包已归档：{target}')
