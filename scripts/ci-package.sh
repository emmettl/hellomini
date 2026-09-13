#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

app="dist/Hello Mini.app"
archive="dist/Hello-Mini-macos-arm64.zip"
codesign --verify --deep --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
(
  cd "$(dirname "$archive")"
  shasum -a 256 "$(basename "$archive")" > "$(basename "$archive").sha256"
)
echo "Created $archive (ad-hoc signed; not notarized)."
