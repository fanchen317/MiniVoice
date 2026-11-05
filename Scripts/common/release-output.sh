#!/usr/bin/env bash
MV_VERSION="$(node -p 'require(process.argv[1]).version' "$ROOT/Shared/version.json")"
[[ "$MV_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]] || { echo '无效发布版本' >&2; exit 2; }
MV_DIST="$ROOT/.build/dist"
MV_COLOR=false
[[ -t 1 && -z "${NO_COLOR:-}" ]] && MV_COLOR=true
mv_note() { if [[ "$MV_COLOR" == true ]]; then printf '\033[36m%s\033[0m\n' "$*"; else printf '%s\n' "$*"; fi; }
mv_ok() { if [[ "$MV_COLOR" == true ]]; then printf '\033[32m✓ %s\033[0m\n' "$*"; else printf '[成功] %s\n' "$*"; fi; }
mv_error() { printf '[失败] %s\n' "$*" >&2; }
