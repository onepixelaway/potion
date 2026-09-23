#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild -project Potion.xcodeproj -scheme Potion -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
printf '\nPotion is ready: %s/build/Build/Products/Debug/Potion.app\n' "$PWD"
