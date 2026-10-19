"""Reject corrupt inputs without loading a model; leave source songs untouched."""
import json
from pathlib import Path
import struct
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
base = root / '.build/lyrics-lite'
checks = []
with tempfile.TemporaryDirectory(prefix='lyrics-reliability-') as directory:
    work = Path(directory)
    def rejected(name, binary, request, expected):
        path = work / (name + '.json')
        output = work / (name + '-output.json')
        path.write_text(json.dumps(request))
        result = subprocess.run([str(binary), str(path), str(output)], capture_output=True, text=True, timeout=10)
        assert result.returncode != 0 and expected in result.stderr, (name, result.stderr)
        assert not output.exists(), name
        checks.append(name)
    for name, payload in [('empty-pcm', b''), ('truncated-pcm', b'abc'),
                          ('nan-pcm', struct.pack('<f', float('nan'))),
                          ('infinite-pcm', struct.pack('<f', float('inf')))]:
        pcm = work / (name + '.f32')
        pcm.write_bytes(payload)
        rejected(name, base / 'bin/lyrics-force', {'pcmPath': str(pcm)},
                 'PCM input' if len(payload) != 4 else 'non-finite PCM')
    template = json.loads((base / 'benchmark/chinese/request.json').read_text())
    for name, fields in [('zero-duration', {'duration': 0}),
                         ('negative-duration', {'duration': -1}),
                         ('empty-lyrics', {'lines': []}),
                         ('oversized-lyrics', {'lines': ['a' * 100001]})]:
        rejected(name, base / 'bin/lyrics-lite', {**template, **fields}, 'Invalid duration or lyrics size')
print(json.dumps({'passed': len(checks), 'checks': checks}, indent=2))
