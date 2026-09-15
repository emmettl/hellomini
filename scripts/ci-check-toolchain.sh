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
# Any Xcode 27 release is accepted, so point updates do not need a script change.
if ! [[ "$xcode_version" =~ ^Xcode\ 27\. ]]; then
  echo "CI requires Xcode 27. Set DEVELOPER_DIR to its Contents/Developer directory." >&2
  exit 1
fi
swift_version="$(swift --version)"
# Swift prints "Swift version 6.4 (" for the initial release and "6.4.1 (" for patches.
if ! [[ "$swift_version" =~ Swift\ version\ 6\.4[.\ ] ]]; then
  echo "CI requires the Swift 6.4 toolchain from Xcode 27." >&2
  exit 1
fi
printf '%s\n' "$xcode_version" "$swift_version" "macOS $macos_version · arm64"
