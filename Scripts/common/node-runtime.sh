#!/usr/bin/env bash
# Selects a supported Node runtime. Xcode build phases start from a minimal
# PATH that can resolve an outdated system Node, and Node 26 breaks packaging.
minivoice_select_node_runtime() {
  local major
  major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  if [[ "$major" -ge 26 || "$major" -lt 20 ]]; then
    for node_candidate in "${NVM_DIR:-$HOME/.nvm}"/versions/node/v{24,22,20}.*/bin/node; do
      if [[ -x "$node_candidate" ]]; then
        export PATH="$(dirname "$node_candidate"):$PATH"
        echo "==> 构建使用 Node $(node --version) LTS（避免当前 Node $major 的打包兼容问题）"
        break
      fi
    done
    major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
    if [[ "$major" -ge 26 || "$major" -lt 20 ]]; then
      echo 'error: 请安装 Node 20/22/24 LTS 后再构建；当前 Node 版本与打包工具不兼容' >&2
      return 1
    fi
  fi
}
