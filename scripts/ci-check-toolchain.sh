#!/bin/bash
set -euo pipefail

test "$(uname -s)" = Darwin
test "$(uname -m)" = arm64
macos_version="$(sw_vers -productVersion)"
if (( ${macos_version%%.*} < 26 )); then
  echo "Hello Mini requires macOS 26 or later." >&2
  exit 1
fi
xcode_version="$(xcodebuild -version)"
if ! [[ "$xcode_version" == $'Xcode 26.6\n'* ]]; then
  echo "CI requires Xcode 26.6. Set DEVELOPER_DIR to its Contents/Developer directory." >&2
  exit 1
fi
swift_version="$(swift --version)"
if ! [[ "$swift_version" == *"Swift version 6.3."* ]]; then
  echo "CI requires the Swift 6.3 toolchain from Xcode 26.6." >&2
  exit 1
fi
printf '%s\n' "$xcode_version" "$swift_version" "macOS $macos_version · arm64"
