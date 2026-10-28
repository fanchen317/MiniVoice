#!/usr/bin/env python3
"""Classify legacy build files without deleting them. Defaults to a preview."""
from pathlib import Path
import argparse, json, shutil
ROOT=Path(__file__).resolve().parents[2]

def plan(root):
    build=root/'.build'; moves=[]
    def add(source,target):
        p=build/source
        if p.exists() or p.is_symlink(): moves.append((p,build/target))
    for name in ['MiniVoice.app','MiniVoice-debug.app']: add(name,'dist/'+name)
    for old,new in {'Android/ui-tests':'reports/android/ui-tests','Android/tests':'reports/android/tests','Android/tag-tests':'reports/android/tag-tests','Shared/UI':'work/shared-ui','Shared/UI-vite-cache':'cache/vite/shared-ui','iOS/DerivedData':'cache/ios/DerivedData','iOS/tests':'reports/ios/tests'}.items(): add(old,new)
    core=build/'Shared/Core'
    if core.exists():
        for p in core.iterdir():
            dest='work/shared-core' if p.name=='minivoice-core' or p.suffix in {'.o','.dylib'} else 'reports/ui'
            add('Shared/Core/'+p.name,dest+'/'+p.name)
    for old,new in {'Android':'work/android','iOS':'work/ios','native':'work/native','staging':'work/staging','offline-ai':'work/offline-ai','lyrics-lite':'work/experiments/lyrics-lite','whisper-lite-source':'cache/whisper-lite-source','lyrics-lite-tools':'cache/legacy/lyrics-lite-tools','ModuleCache':'cache/legacy/clang-modules','npm-cache':'cache/npm','electron-cache':'cache/electron','dmg-tools':'cache/dmg-tools','android-sdk':'cache/android-sdk','review':'reports/review','blur-review':'reports/blur-review','lyrics-audit':'reports/lyrics-audit','artwork-audit':'reports/artwork-audit'}.items(): add(old,new)
    for name in ['index-build','browse-audit','xcode-scratch','npm-offline-validation']:
        add(name,'cache/legacy/'+name)
        add('archive/legacy-layout/'+name,'cache/legacy/'+name)
    known={p for p,_ in moves}
    if build.exists():
        for p in build.iterdir():
            if p.name in {'cache','work','reports','archive','dist','Shared'} or p in known: continue
            if p.name.startswith('electron-') and p.suffix=='.zip': target='cache/electron/'+p.name
            elif p.suffix in {'.txt','.log','.png'}: target='reports/legacy/'+p.name
            elif p.name in {'out','checkouts','repositories','artifacts','debug','release','build.db','manifest.pif','workspace-state.json','CACHEDIR.TAG','.lock'} or p.name.startswith(('.buildSystem','arm64-','x86_64-')): target='cache/legacy-swift/'+p.name
            else: target='archive/legacy-layout/'+p.name
            moves.append((p,build/target))
    for old,new in [('MacOS/.build','cache/legacy/macos-swift'),('Shared/Core/.build','cache/legacy/shared-core-swift')]:
        if (root/old).exists():moves.append((root/old,build/new))
    return moves

def migrate(root,apply=False):
    build=root/'.build'
    if (build/'package-workflow.lock').exists() or (build/'work/package-workflow.lock').exists(): raise RuntimeError('构建正在运行，暂不迁移')
    moves=[]; destinations=set()
    for source,target in plan(root):
        if target.exists() or target.is_symlink() or target in destinations:
            relative=source.relative_to(build) if source.is_relative_to(build) else source.relative_to(root)
            target=build/'archive/pre-migration'/relative
        if target in destinations: raise RuntimeError(f'迁移目标重复：{target}')
        destinations.add(target)
        moves.append((source,target))
    # Refuse collisions before moving anything, preserving both copies.
    for source,target in moves:
        if target.exists() or target.is_symlink(): raise RuntimeError(f'目标已存在，未执行迁移：{target}')
    if apply:
        for name in ['cache','work','reports','archive','dist']:(build/name).mkdir(parents=True,exist_ok=True)
    for source,target in moves:
        print(f'{source.relative_to(root)} -> {target.relative_to(root)}')
        if apply:
            target.parent.mkdir(parents=True,exist_ok=True);source.rename(target)
    if apply:
        for folder in [build/'Shared/Core',build/'Shared']:
            if folder.exists() and not any(folder.iterdir()):folder.rmdir()
        link=build/'work/android/MiniVoice-debug.apk'
        if link.is_symlink():link.unlink();link.symlink_to('../../dist/MiniVoice-android-experience.apk')
        # Reuse source-control dependencies, never compiled objects with absolute paths.
        old=build/'cache/legacy-swift'; new=build/'cache/swift'
        if (old/'workspace-state.json').exists() and not (new/'workspace-state.json').exists():
            new.mkdir(parents=True,exist_ok=True)
            for name in ['checkouts','repositories']:
                if (old/name).exists():shutil.copytree(old/name,new/name,dirs_exist_ok=True,symlinks=True)
            shutil.copyfile(old/'workspace-state.json',new/'workspace-state.json')
        manifest=build/'reports/build-layout-migration.json'
        history=json.loads(manifest.read_text()) if manifest.exists() else []
        history.extend({'from':str(a.relative_to(root)),'to':str(b.relative_to(root))} for a,b in moves)
        manifest.write_text(json.dumps(history,ensure_ascii=False,indent=2)+'\n')
    return moves
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--apply',action='store_true');args=parser.parse_args()
    migrate(ROOT,args.apply)
