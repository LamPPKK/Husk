#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Build Husk native macOS application for Intel (x86_64).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HUSK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$HUSK_ROOT/build/macos"
OUT_APP="$BUILD_DIR/Husk.app"
OUT_ZIP="$BUILD_DIR/Husk-macOS-x86_64.zip"

if [ -z "${DEVELOPER_DIR:-}" ]; then
    if [ -n "${MD_APPLE_SDK_ROOT:-}" ] && [ -d "${MD_APPLE_SDK_ROOT}/Contents/Developer" ]; then
        export DEVELOPER_DIR="${MD_APPLE_SDK_ROOT}/Contents/Developer"
    elif [ -d "/Applications/Xcode_16.2.app/Contents/Developer" ]; then
        export DEVELOPER_DIR="/Applications/Xcode_16.2.app/Contents/Developer"
    elif [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
        export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    else
        export DEVELOPER_DIR="$(xcode-select -p)"
    fi
fi

echo "=========================================================="
echo "  Building Husk for macOS (Intel x86_64)"
echo "=========================================================="

# 1. Regenerate Xcode project if xcodegen is present
if command -v xcodegen >/dev/null 2>&1; then
    echo "==> Regenerating Xcode project from project.yml..."
    (cd "$HUSK_ROOT/src/app" && xcodegen generate)
else
    echo "==> Warning: xcodegen not found in PATH, using existing project." >&2
fi

# 2. Build HuskMac scheme with xcodebuild
echo "==> Building HuskMac target (Release, x86_64)..."
DERIVED_DATA="$BUILD_DIR/DerivedData"
rm -rf "$DERIVED_DATA"
mkdir -p "$BUILD_DIR"

xcodebuild -project "$HUSK_ROOT/src/app/Husk.xcodeproj" \
    -scheme HuskMac \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    ARCHS=x86_64 \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

BUILT_APP="$DERIVED_DATA/Build/Products/Release/HuskMac.app"

if [ ! -d "$BUILT_APP" ]; then
    echo "Error: Built app not found at $BUILT_APP" >&2
    exit 1
fi

# 3. Stage into build/macos/Husk.app
echo "==> Staging into $OUT_APP..."
rm -rf "$OUT_APP"
cp -R "$BUILT_APP" "$OUT_APP"

# 4. Ad-hoc codesign with entitlements
ENTITLEMENTS="$HUSK_ROOT/src/app/HuskMac/HuskMac.entitlements"
if [ -f "$ENTITLEMENTS" ]; then
    echo "==> Signing Husk.app with JIT entitlements..."
    codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$OUT_APP"
fi

# 5. Package as ZIP for distribution
echo "==> Packaging into $OUT_ZIP..."
rm -f "$OUT_ZIP"
(cd "$BUILD_DIR" && zip -r -y -q "Husk-macOS-x86_64.zip" "Husk.app")

# 6. Verify binary architecture
echo "==> Verification:"
file "$OUT_APP/Contents/MacOS/HuskMac"
codesign -d --entitlements :- "$OUT_APP" 2>&1 | head -n 20 || true

echo "=========================================================="
echo "  Successfully built Husk for macOS (x86_64)!"
echo "  App bundle: $OUT_APP"
echo "  Zip archive: $OUT_ZIP"
echo "=========================================================="
