#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${1:-debug}"
case "$configuration" in
  debug|release) ;;
  *) echo "Usage: $0 [debug|release]" >&2; exit 1 ;;
esac

swift build -c "$configuration"
make icons
binary_directory="$(swift build -c "$configuration" --show-bin-path)"
app_directory="$PWD/dist/Hello Mini.app"
mkdir -p "$app_directory/Contents/MacOS"
mkdir -p "$app_directory/Contents/Resources"
cp "$binary_directory/HelloMini" "$app_directory/Contents/MacOS/HelloMini"
cp Support/Info.plist "$app_directory/Contents/Info.plist"
cp Support/AppIcon.icns "$app_directory/Contents/Resources/AppIcon.icns"
cp LICENSE "$app_directory/Contents/Resources/LICENSE.txt"
cp THIRD_PARTY_NOTICES.md "$app_directory/Contents/Resources/THIRD_PARTY_NOTICES.md"
cp Sources/MiniTeapot/Resources/Teapot-LICENSE.txt "$app_directory/Contents/Resources/Teapot-LICENSE.txt"
python3 scripts/bundle-resources.py "$binary_directory" "$app_directory"
codesign --force --sign - "$app_directory"
echo "Built $app_directory"
