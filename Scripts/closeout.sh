#!/bin/zsh
# Full validation loop: build, test, lint, dead-code scan.
# Run from anywhere; exits nonzero on the first failure.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▸ swift build — packages/DotsUI"
swift build --package-path packages/DotsUI

echo "▸ swift build — packages/Dots"
swift build --package-path packages/Dots

echo "▸ swift test — packages/Dots"
swift test --package-path packages/Dots

echo "▸ swift build — tools/dots-capture-host"
swift build --package-path tools/dots-capture-host

echo "▸ xcodegen + xcodebuild — apps/macos"
(cd apps/macos && xcodegen generate --quiet)
xcodebuild -project apps/macos/Dots.xcodeproj -scheme Dots -configuration Debug \
  -derivedDataPath DerivedData -quiet build

echo "▸ swiftlint"
swiftlint --strict --quiet

echo "▸ periphery"
periphery scan --quiet

echo "✓ closeout clean"
