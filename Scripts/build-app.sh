#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
cd "$project_dir"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_dir/.build/ModuleCache"

swift build -c release
bundle_dir="$project_dir/build/MiniVoice.app"
rm -rf "$bundle_dir"
mkdir -p "$bundle_dir/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/MiniVoice" "$bundle_dir/Contents/MacOS/MiniVoice"
cp "$project_dir/AppBundle/Info.plist" "$bundle_dir/Contents/Info.plist"
codesign --force --sign - "$bundle_dir"
echo "已生成：$bundle_dir"
