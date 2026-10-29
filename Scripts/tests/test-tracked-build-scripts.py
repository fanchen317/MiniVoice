#!/usr/bin/env python3
"""Reproduce another checkout: build using only files present in the Git index."""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
required = [
    'Scripts/build/build-ios-ui.sh', 'Scripts/build/build-ios.sh',
    'Scripts/build/build-shared-ui.sh', 'Scripts/build/package-ios.sh',
    'Scripts/build/package-all.sh', 'Scripts/build/build-android.sh',
    'Scripts/common/node-runtime.sh',
]
for path in required:
    subprocess.run(['git', 'ls-files', '--error-unmatch', path], cwd=root,
                   check=True, stdout=subprocess.DEVNULL)
    result = subprocess.run(['git', 'check-ignore', '--no-index', path], cwd=root,
                            capture_output=True)
    assert result.returncode == 1, f'Build source ignored again: {path}'
assert subprocess.run(['git', 'check-ignore', '--no-index', 'build/generated.tmp'],
                      cwd=root, capture_output=True).returncode == 0
with tempfile.TemporaryDirectory(prefix='minivoice-git-checkout-') as directory:
    checkout = Path(directory) / 'source'
    checkout.mkdir()
    subprocess.run(['git', 'checkout-index', '--all', '--prefix=' + str(checkout) + '/'],
                   cwd=root, check=True)
    assert all((checkout / path).is_file() for path in required)
    assert not (checkout / 'Shared/UI/node_modules').exists()
    assert not (checkout / 'MacOS/Desktop/node_modules').exists()
    env = os.environ.copy()
    # Match Xcode's reduced PATH, including the older system Node if present.
    env['PATH'] = '/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin'
    result = subprocess.run(['bash', str(checkout / 'Scripts/build/build-shared-ui.sh')],
                            cwd='/tmp', env=env, capture_output=True, text=True)
    report = root / '.build/reports/merge-repair'
    report.mkdir(parents=True, exist_ok=True)
    (report / 'clean-index-build.log').write_text(result.stdout + result.stderr)
    if result.returncode:
        print(result.stdout + result.stderr)
        raise SystemExit(result.returncode)
    output = checkout / '.build/work/shared-ui'
    assert (output / 'index.html').is_file()
    assert (output / 'assets/THIRD_PARTY_NOTICES.txt').is_file()
    assert not (checkout / 'MacOS/Desktop/node_modules').exists()
print('PASS Git-only clean export, tracked build scripts, root-only ignore and reduced-PATH offline UI build')
