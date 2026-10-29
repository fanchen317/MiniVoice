#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEVICE="${1:?请提供专用 MiniVoice Shared iOS 模拟器 UUID}"
# Refuse the user's everyday simulator and all real devices.
xcrun simctl list devices -j | python3 -c 'import json,sys; d=[v for rows in json.load(sys.stdin)["devices"].values() for v in rows if v["udid"]==sys.argv[1]]; assert d and d[0]["name"].startswith("MiniVoice Shared iOS"), "只允许 MiniVoice Shared iOS 专用模拟器"' "$DEVICE"
APP="$ROOT/.build/cache/ios/DerivedData/Build/Products/Debug-iphonesimulator/MiniVoice.app"
[[ -d "$APP" ]] || { echo '请先运行 Scripts/build/build-ios.sh simulator Debug' >&2; exit 1; }
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl terminate "$DEVICE" com.xcosmos.MiniVoice.ios 2>/dev/null || true
xcrun simctl install "$DEVICE" "$APP"
CONTAINER="$(xcrun simctl get_app_container "$DEVICE" com.xcosmos.MiniVoice.ios data)"
REPORT="$CONTAINER/Documents/shared-host-smoke.json"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
MARKER="$CONTAINER/Documents/.shared-smoke-$RUN_ID"
touch "$MARKER"
rm -f "$REPORT"
xcrun simctl launch "$DEVICE" com.xcosmos.MiniVoice.ios --mv-ui-fixture --mv-ui-smoke
for attempt in {1..90}; do
  [[ -f "$REPORT" ]] && break
  sleep 1
done
[[ -f "$REPORT" ]] || { echo 'WKWebView 集成测试未返回报告' >&2; exit 1; }
OUTPUT="$ROOT/.build/reports/ios/shared-ui/$DEVICE/$RUN_ID"
mkdir -p "$OUTPUT"
cp "$REPORT" "$OUTPUT/report.json"
for screenshot in "$CONTAINER/Documents/"*.png; do
  [[ -f "$screenshot" && "$screenshot" -nt "$MARKER" ]] && cp "$screenshot" "$OUTPUT/"
done
python3 - "$APP" "$OUTPUT" "$DEVICE" "$RUN_ID" <<'MANIFEST'
import hashlib,json,pathlib,sys
app,out=map(pathlib.Path,sys.argv[1:3])
files=[app/'MiniVoice',*sorted((app/'SharedPlayer').rglob('*'))]
manifest={'device':sys.argv[3],'run':sys.argv[4],'files':{str(p.relative_to(app)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files if p.is_file()},'screenshots':sorted(p.name for p in out.glob('*.png'))}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2))
MANIFEST
if [[ -f "$CONTAINER/Documents/diagnostics-test.zip" && "$CONTAINER/Documents/diagnostics-test.zip" -nt "$MARKER" ]]; then
 cp "$CONTAINER/Documents/diagnostics-test.zip" "$OUTPUT/"
 python3 - "$OUTPUT/diagnostics-test.zip" <<'DIAGNOSTICS'
import json,sys,zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
    assert archive.testzip() is None
    report=json.loads(archive.read('diagnostics.json'))
    records=report['diagnostics']['records']
    assert any(r['detail']=='process started' for r in records)
    assert any(r['kind']=='failure' and 'host:' in r['detail'] for r in records)
    assert sum(r['kind']=='crash' for r in records)<=5
    assert len(records)<=205
    print('PASS actual host diagnostics ZIP, events, failures and retention limits')
DIAGNOSTICS
fi
rm -f "$MARKER"
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print(json.dumps(r,ensure_ascii=False,indent=2)); assert r.get("ok"), r.get("error","WKWebView 测试失败")' "$REPORT"
echo "报告：$OUTPUT"
