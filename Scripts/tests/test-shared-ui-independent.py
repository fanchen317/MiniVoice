#!/usr/bin/env python3
"""Verify an offline shared UI build without installing the Mac front end."""
from pathlib import Path
import tempfile,shutil,subprocess
root=Path(__file__).resolve().parents[2]
(root/'.build/reports').mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='minivoice-independent-ui-') as folder:
    target=Path(folder)
    for rel in ['Scripts','Shared/UI','Shared/Tooling','Shared/Core/Sources/MiniVoiceCore/vendor','MacOS/Desktop/src','Android/app/src/main']:
        shutil.copytree(root/rel,target/rel,ignore=shutil.ignore_patterns('node_modules','.build','__pycache__'))
    assert not (target/'MacOS/Desktop/node_modules').exists()
    result=subprocess.run(['bash',str(target/'Scripts/build/build-shared-ui.sh')],cwd='/tmp',capture_output=True,text=True)
    (root/'.build/reports/independent-shared-ui-build.log').write_text(result.stdout+result.stderr)
    print(result.stdout[-1400:]+result.stderr)
    if result.returncode:raise SystemExit(result.returncode)
    assert (target/'.build/work/shared-ui/index.html').is_file()
    assert not (target/'MacOS/Desktop/node_modules').exists()
    print('PASS clean offline build from another cwd, without MacOS/Desktop/node_modules')
