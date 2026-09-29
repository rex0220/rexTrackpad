#!/bin/bash
# Builds the distributable zip for GitHub Releases.
#
#     scripts/release.sh
#
# Output: dist/rexTrackpad-<version>.zip and its SHA-256 checksum.
#
# The app is ad-hoc signed on purpose: releases are not signed with a Developer ID
# or notarized, and a local Apple Development certificate (which embeds the
# developer's e-mail address) must not end up in a public download. Users open the
# app once via System Settings › Privacy & Security › "Open Anyway" (see README).
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT=rexTrackpad.xcodeproj
SCHEME=rexTrackpad
BUILD_DIR=build/release
DIST_DIR=dist

VERSION=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ MARKETING_VERSION = / { print $2; exit }')
# Build number = number of commits, so every release build gets a higher number.
BUILD_NUMBER=$(git rev-list --count HEAD)

echo "Building rexTrackpad ${VERSION} (${BUILD_NUMBER})"

rm -rf "$BUILD_DIR"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$BUILD_DIR" \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    build | grep -E 'error:|warning:|\*\* BUILD' || true

APP="$BUILD_DIR/Build/Products/Release/rexTrackpad.app"
if [ ! -d "$APP" ]; then
    echo "Build failed: $APP not found" >&2
    exit 1
fi

codesign --verify --deep --strict "$APP"
if codesign -dv "$APP" 2>&1 | grep -q '^Authority='; then
    echo "Expected an ad-hoc signature, but the app is signed with a certificate" >&2
    exit 1
fi
ARCHS_BUILT=$(lipo -archs "$APP/Contents/MacOS/rexTrackpad")
for arch in arm64 x86_64; do
    if [[ " $ARCHS_BUILT " != *" $arch "* ]]; then
        echo "Missing architecture $arch (built: $ARCHS_BUILT)" >&2
        exit 1
    fi
done

mkdir -p "$DIST_DIR"
ZIP="$DIST_DIR/rexTrackpad-${VERSION}.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
(cd "$DIST_DIR" && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")

echo "Created $ZIP"
cat "$ZIP.sha256"
