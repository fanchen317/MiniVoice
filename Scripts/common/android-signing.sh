#!/usr/bin/env bash
# Shared signing policy. Never create or silently substitute a signing identity.
minivoice_check_signing() {
  local signing_repo="$1" expected
  keystore="${MINIVOICE_KEYSTORE:-$signing_repo/Android/signing/debug.keystore}"
  key_alias="${MINIVOICE_KEY_ALIAS:-androiddebugkey}"
  export MINIVOICE_STORE_PASSWORD="${MINIVOICE_STORE_PASSWORD:-android}"
  export MINIVOICE_KEY_PASSWORD="${MINIVOICE_KEY_PASSWORD:-$MINIVOICE_STORE_PASSWORD}"
  if [[ ! -f "$keystore" || ! -f "$signing_repo/Android/signing-certificate.sha256" ]]; then
    printf '缺少统一签名密钥或证书指纹。请先从旧 Mac 导入手机上已安装版本的原始密钥，参见 Android/README.md。不会自动生成新密钥。\n' >&2
    return 1
  fi
  signing_fingerprint="$(keytool -exportcert -keystore "$keystore" -storepass:env MINIVOICE_STORE_PASSWORD -alias "$key_alias" | shasum -a 256 | awk '{print $1}')" || return 1
  expected="$(tr -d '[:space:]' < "$signing_repo/Android/signing-certificate.sha256")"
  if [[ ! "$expected" =~ ^[0-9a-f]{64}$ || "$signing_fingerprint" != "$expected" ]]; then
    printf '签名证书与项目固定指纹不一致，已停止。请使用另一台 Mac 相同的原始密钥，不要修改指纹来绕过检查。\n' >&2
    return 1
  fi
}
