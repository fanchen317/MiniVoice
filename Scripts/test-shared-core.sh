#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
bash Scripts/build-shared-core.sh
output="$repo_root/.build/Shared/Core"
javac -encoding UTF-8 -d "$output/classes" Android/app/src/main/java/com/xcosmos/minivoice/SharedCore.java Shared/Core/Tests/JVM/ProtocolCLI.java
swift test --package-path Shared/Core
swift_bin="$(swift build --package-path Shared/Core --show-bin-path)"
python3 - "$output" "$swift_bin" <<'PY'
import json,subprocess,sys,pathlib
out,swift=sys.argv[1:]
fixtures=json.loads(pathlib.Path('Shared/Core/Tests/fixtures.json').read_text())
payload=''.join(json.dumps(row['request'],ensure_ascii=False)+'\n' for row in fixtures)
commands=[[out+'/minivoice-core'],['java','-Djava.library.path='+out,'-cp',out+'/classes','com.xcosmos.minivoice.ProtocolCLI'],[swift+'/SharedCoreCLI']]
results=[]
for command in commands:
    run=subprocess.run(command,input=payload,text=True,capture_output=True,check=True)
    responses=[json.loads(line) for line in run.stdout.splitlines()]
    assert len(responses)==len(fixtures),(command,run.stdout,run.stderr)
    for fixture,response in zip(fixtures,responses):
        assert response['ok']==fixture.get('ok',True),(fixture,response)
        if 'value' in fixture: assert response['value']==fixture['value'],(fixture,response)
    results.append(responses)
assert results[0]==results[1]==results[2]
print('PASS C ABI / JVM JNI / Swift: '+str(len(fixtures))+' identical protocol fixtures')
PY
node --test Shared/UI/test/*.test.mjs
