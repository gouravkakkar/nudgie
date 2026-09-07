#!/bin/bash
# Builds a universal (Apple Silicon + Intel) release and assembles build/Nudgie.app with an ad-hoc signature.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=Nudgie
OUT="build/$APP.app"
[ -f LICENSE ] || { echo "LICENSE is missing; see README → Licence" >&2; exit 1; }

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

# Sign with a Developer ID Application certificate when one is available: that is the only
# kind Apple will notarise, and notarised apps open on a double-click with no Gatekeeper
# detour. Without one, fall back to an ad-hoc signature so anyone can still build and run.
IDENTITY="${NUDGIE_SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null |
    sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1)}"

if [ -n "$IDENTITY" ]; then
    # --options runtime (hardened runtime) and --timestamp are both required for notarisation.
    codesign --force --timestamp --options runtime \
        --sign "$IDENTITY" --identifier com.gouravkakkar.nudgie "$OUT"
    echo "Signed with: $IDENTITY"
    echo "Next: ./tools/notarize.sh"
else
    codesign --force --sign - --identifier com.gouravkakkar.nudgie "$OUT"
    echo "Ad-hoc signed: no Developer ID Application certificate on this Mac."
    echo "Fine for running it yourself; anyone else will meet Gatekeeper. See docs/releasing.md."
fi

echo "Built $OUT ($(lipo -archs "$OUT/Contents/MacOS/$APP"))"
