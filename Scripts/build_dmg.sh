#!/usr/bin/env bash
#
# build_dmg.sh — build a locally-signed Spitr.app and package it as a DMG.
#
# No paid Apple Developer account and no external tools are required: this uses
# the project's automatic ("Sign to Run Locally" / Personal Team) signing and
# ships only `xcodebuild` + `hdiutil`. The result is NOT notarized, so macOS
# Gatekeeper will quarantine it on first launch — see the note printed at the end
# and the README install section.
#
# Usage:
#   Scripts/build_dmg.sh                 # build + package into ./dist
#   TEAM_ID=XXXXXXXXXX Scripts/build_dmg.sh   # override the signing team
#
set -euo pipefail

SCHEME="Spitr"
CONFIG="Release"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$REPO/build"
DIST_DIR="$REPO/dist"
ARCHIVE="$BUILD_DIR/Spitr.xcarchive"

cd "$REPO"
rm -rf "$ARCHIVE"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

echo "==> Archiving $SCHEME ($CONFIG)…"
xcodebuild archive \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -archivePath "$ARCHIVE" \
    ${TEAM_ID:+DEVELOPMENT_TEAM="$TEAM_ID"} \
    | tail -5

APP="$ARCHIVE/Products/Applications/Spitr.app"
if [[ ! -d "$APP" ]]; then
    echo "error: archive did not produce $APP" >&2
    exit 1
fi

# Pull the marketing version straight from the built app so the DMG name always
# matches what shipped.
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$DIST_DIR/Spitr-$VERSION.dmg"
echo "==> Built Spitr.app version $VERSION"

# Stage the app next to an /Applications symlink so the DMG offers drag-install.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating ${DMG}…"
rm -f "$DMG"
hdiutil create \
    -volname "Spitr $VERSION" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG" >/dev/null

# Publish the checksum alongside the DMG for release verification.
( cd "$DIST_DIR" && shasum -a 256 "$(basename "$DMG")" | tee "$(basename "$DMG").sha256" )

echo
echo "==> Done: $DMG"
echo
echo "This DMG is self-signed and NOT notarized. On first launch the user must"
echo "clear the quarantine flag once — document this in the release notes:"
echo "  • right-click Spitr.app → Open → Open, or"
echo "  • xattr -dr com.apple.quarantine /Applications/Spitr.app"
