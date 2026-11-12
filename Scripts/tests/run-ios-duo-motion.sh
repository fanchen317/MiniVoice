#!/usr/bin/env bash
set -euo pipefail
device="${1:?专用UUID}"; tag="${2:?本次标签}"
[[ "$tag" =~ ^[a-z0-9-]+$ ]] || exit 2
xcrun simctl list devices -j | python3 -c 'import json,sys; d=[v for rows in json.load(sys.stdin)["devices"].values() for v in rows if v["udid"]==sys.argv[1]]; assert d and d[0]["name"].startswith("MiniVoice Shared iOS")' "$device"
container="$(xcrun simctl get_app_container "$device" com.xcosmos.MiniVoice.ios data)";output=".build/reports/ios/fold-motion/$tag";mkdir -p "$output"
rm -f "$container/Documents/shared-host-smoke.json"
xcrun simctl terminate "$device" com.xcosmos.MiniVoice.ios 2>/dev/null || true
fixture_args=(--mv-ui-fixture --mv-ui-smoke --mv-duo-motion-smoke)
if [[ "${3:-}" != playing ]]; then fixture_args+=(--mv-ui-idle-fixture); fi
xcrun simctl launch "$device" com.xcosmos.MiniVoice.ios "${fixture_args[@]}"
for attempt in {1..55}; do [[ -f "$container/Documents/shared-host-smoke.json" ]] && break; sleep 1; done
cp "$container/Documents/shared-host-smoke.json" "$output/report.json"
xcrun simctl io "$device" screenshot "$output/screen.png" >/dev/null
python3 - "$output/report.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]));print({k:r.get(k) for k in ['ok','error','initial','target','expected','intermediate','aligned']});assert r.get('ok'),r.get('error','native divider interpolation failed')
PY
