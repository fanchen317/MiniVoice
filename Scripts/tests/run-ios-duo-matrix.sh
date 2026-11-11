#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
device="${1:?专用模拟器UUID}"
pose="${2:?姿态标签}"
[[ "$pose" =~ ^[a-z0-9-]+$ ]] || exit 2
xcrun simctl list devices -j | python3 -c 'import json,sys; d=[v for rows in json.load(sys.stdin)["devices"].values() for v in rows if v["udid"]==sys.argv[1]]; assert d and d[0]["name"].startswith("MiniVoice Shared iOS"), "只允许专用模拟器"' "$device"
container="$(xcrun simctl get_app_container "$device" com.xcosmos.MiniVoice.ios data)"
output="$root/.build/reports/ios/duo-matrix/$pose"
mkdir -p "$output"
marker="$container/Documents/.duo-matrix-marker"
touch "$marker"
rm -f "$container/Documents/shared-host-smoke.json"
xcrun simctl terminate "$device" com.xcosmos.MiniVoice.ios 2>/dev/null || true
xcrun simctl launch "$device" com.xcosmos.MiniVoice.ios --mv-ui-fixture --mv-ui-smoke --mv-duo-matrix-smoke
for attempt in {1..160}; do
 [[ -f "$container/Documents/shared-host-smoke.json" ]] && break
 sleep 1
done
cp "$container/Documents/shared-host-smoke.json" "$output/report.json"
for file in "$container/Documents/"matrix-*.png; do
 [[ -f "$file" && "$file" -nt "$marker" ]] && cp "$file" "$output/"
done
rm -f "$marker"
python3 - "$output/report.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]));print(json.dumps({'ok':r.get('ok'),'error':r.get('error'),'rows':len(r.get('rows',[])),'failures':len(r.get('failures',[]))}));assert r.get('ok'), str(r.get('failures',[])[:1])[:1000]
PY
