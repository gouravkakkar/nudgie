#!/bin/bash
# Builds a universal (Apple Silicon + Intel) release and assembles build/Nudgie.app with an ad-hoc signature.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=Nudgie
OUT="build/$APP.app"
[ -f LICENSE ] || { echo "LICENSE is missing; run Task 13 step 0 first" >&2; exit 1; }

# Two --arch flags make SwiftPM emit a fat binary under .build/apple/Products/Release (verified on this Mac).
swift build -c release --arch arm64 --arch x86_64 2>&1 | tail -1
BIN=".build/apple/Products/Release/$APP"
lipo -info "$BIN" | grep -q "x86_64 arm64" || { echo "expected a universal binary, got: $(lipo -info "$BIN")" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/$APP"
cp Resources/Info.plist "$OUT/Contents/Info.plist"
cp Resources/Nudgie.icns "$OUT/Contents/Resources/Nudgie.icns"
cp LICENSE "$OUT/Contents/Resources/LICENSE"
printf 'APPL????' > "$OUT/Contents/PkgInfo"

codesign --force --sign - --identifier com.gouravkakkar.nudgie "$OUT"
echo "Built $OUT ($(lipo -archs "$OUT/Contents/MacOS/$APP"))"
