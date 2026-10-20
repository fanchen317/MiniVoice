#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 1 || ! -f "$1" ]]; then
  printf '用法：bash Scripts/import-android-signing.sh /旧Mac原始密钥/debug.keystore\n' >&2; exit 1
fi
export MINIVOICE_STORE_PASSWORD="${MINIVOICE_STORE_PASSWORD:-android}"
export MINIVOICE_KEY_PASSWORD="${MINIVOICE_KEY_PASSWORD:-$MINIVOICE_STORE_PASSWORD}"
key_alias="${MINIVOICE_KEY_ALIAS:-androiddebugkey}"
# Exporting a public certificate does not expose the private signing key.
fingerprint="$(keytool -exportcert -keystore "$1" -storepass:env MINIVOICE_STORE_PASSWORD -alias "$key_alias" | shasum -a 256 | awk '{print $1}')"
identity="$repo_root/Android/signing-certificate.sha256"
if [[ -f "$identity" && "$(tr -d '[:space:]' < "$identity")" != "$fingerprint" ]]; then
  printf '该密钥与项目已固定的证书不同，拒绝替换。请找回原始密钥。\n' >&2; exit 1
fi
# Verify a private key is present, not just a trusted certificate entry.
LC_ALL=C keytool -list -v -keystore "$1" -storepass:env MINIVOICE_STORE_PASSWORD -alias "$key_alias" | rg -q 'PrivateKeyEntry'
mkdir -p "$repo_root/Android/signing"
target="$repo_root/Android/signing/debug.keystore"
if [[ ! "$1" -ef "$target" ]]; then
  if [[ -f "$target" ]]; then
    backup="$target.backup.$(date +%Y%m%d%H%M%S).$$"; cp -p "$target" "$backup"; chmod 600 "$backup"
  fi
  cp "$1" "$target"
fi
chmod 700 "$repo_root/Android/signing"; chmod 600 "$target"
printf '%s\n' "$fingerprint" > "$identity"
printf '已导入统一签名。证书 SHA-256：%s\n请将开发密钥 Android/signing/debug.keystore 与 signing-certificate.sha256 一起提交并同步到另一台 Mac。\n' "$fingerprint"
