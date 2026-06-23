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
#   ADHOC_SIGN=1 Scripts/build_dmg.sh    # ad-hoc sign, no team (CI / no certs)
#
# ADHOC_SIGN=1 builds without the Personal-Team certificate: it signs the app
# ad-hoc ("-") and disables the hardened runtime, so the archive succeeds on a
# runner that has no signing identity (e.g. GitHub Actions). The resulting DMG is
# even less trusted than the locally-signed one — still not notarized — but it
# launches after the same one-time quarantine clear.
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

# Ad-hoc mode overrides the project's Automatic/Personal-Team signing so the
# archive needs no certificate. Values without spaces, so unquoted word-splitting
# into separate xcodebuild build-setting args is intentional.
SIGN_FLAGS=""
if [[ "${ADHOC_SIGN:-0}" == "1" ]]; then
    SIGN_FLAGS="CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= ENABLE_HARDENED_RUNTIME=NO"
fi

echo "==> Archiving $SCHEME ($CONFIG)…"
# shellcheck disable=SC2086  # SIGN_FLAGS must word-split into separate args
xcodebuild archive \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -archivePath "$ARCHIVE" \
    ${TEAM_ID:+DEVELOPMENT_TEAM="$TEAM_ID"} \
    $SIGN_FLAGS \
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

# Build a proper install window: large icons, a drag-to-Applications background
# with an arrow, no toolbar, and the app's own icon on the mounted volume. This
# needs a read-write image first (UDRW): stage the background + .VolumeIcon.icns,
# lay the window out via Finder, flag the volume custom-icon, then compress.
VOLNAME="Spitr $VERSION"
APPICON="$APP/Contents/Resources/AppIcon.icns"
BACKGROUND="$REPO/Scripts/assets/dmg-background.png"

# Build a multi-size volume icon from the app icon. The app ships a single 256px
# representation; a one-size .icns renders blank at the 16px proxy/status sizes,
# so re-derive all the small/medium sizes the title bar and status bar need.
if [[ -f "$APPICON" ]]; then
    ICONSET="$STAGE/.vol.iconset"
    mkdir -p "$ICONSET"
    SRC_PNG="$STAGE/.vol-src.png"
    sips -s format png "$APPICON" --out "$SRC_PNG" >/dev/null
    for spec in 16:16x16 32:16x16@2x 32:32x32 64:32x32@2x 128:128x128 256:128x128@2x 256:256x256; do
        sips -z "${spec%%:*}" "${spec%%:*}" "$SRC_PNG" --out "$ICONSET/icon_${spec##*:}.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$STAGE/.VolumeIcon.icns"
    # Finder deletes a staged .VolumeIcon.icns while it lays out the window, so
    # keep a copy outside the image and re-place it after the layout step.
    KEEP_ICNS="$BUILD_DIR/VolumeIcon.icns"
    cp "$STAGE/.VolumeIcon.icns" "$KEEP_ICNS"
    rm -rf "$ICONSET" "$SRC_PNG"
fi

if [[ -f "$BACKGROUND" ]]; then
    mkdir -p "$STAGE/.background"
    cp "$BACKGROUND" "$STAGE/.background/background.png"
fi

echo "==> Creating ${DMG}…"
rm -f "$DMG"
RW_DMG="$BUILD_DIR/Spitr-rw.dmg"
rm -f "$RW_DMG"
hdiutil create \
    -volname "$VOLNAME" \
    -srcfolder "$STAGE" \
    -ov -format UDRW \
    "$RW_DMG" >/dev/null

MOUNT="/Volumes/$VOLNAME"
# Eject any stale mounts of this volume name before attaching. Repeated dev
# builds (and open Finder windows) pile them up; a leftover makes hdiutil attach
# land on "… 1" while SetFile/Finder target the old volume — the icon and layout
# then silently miss. If one can't be ejected, abort loudly instead of writing
# to the wrong volume.
for v in "/Volumes/$VOLNAME"*; do
    [[ -e "$v" ]] || continue
    echo "    ejecting stale $v"
    hdiutil detach "$v" -force >/dev/null 2>&1 \
        || diskutil unmount force "$v" >/dev/null 2>&1 || true
done
if compgen -G "/Volumes/$VOLNAME*" >/dev/null 2>&1; then
    echo "error: a '$VOLNAME' volume is still mounted — run 'killall Finder' to" >&2
    echo "       release open windows, then re-run this script." >&2
    exit 1
fi
hdiutil attach "$RW_DMG" -quiet >/dev/null

# Arrange the install window. Controlling Finder needs Automation permission —
# the first run prompts "Terminal wants to control Finder"; approve it once.
if [[ -f "$BACKGROUND" ]]; then
    osascript <<EOF || echo "warn: Finder layout skipped (Automation permission?)" >&2
tell application "Finder"
    tell disk "$VOLNAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 560}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 128
        set text size of opts to 16
        set background picture of opts to file ".background:background.png"
        set position of item "Spitr.app" of container window to {165, 195}
        set position of item "Applications" of container window to {495, 195}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF
fi

# Now (after Finder has finished and can't delete it) place the volume icon and
# stamp it: the .VolumeIcon.icns needs creator code "icnC" AND the volume root
# needs the "has custom icon" bit — both, or the title/path-bar icon stays blank.
if [[ -n "${KEEP_ICNS:-}" && -f "$KEEP_ICNS" ]]; then
    cp "$KEEP_ICNS" "$MOUNT/.VolumeIcon.icns"
    SetFile -c icnC "$MOUNT/.VolumeIcon.icns"
    SetFile -a C "$MOUNT"
fi

sync
hdiutil detach "$MOUNT" -quiet
hdiutil convert "$RW_DMG" -format UDZO -ov -o "$DMG" >/dev/null
rm -f "$RW_DMG"

# Publish the checksum alongside the DMG for release verification.
( cd "$DIST_DIR" && shasum -a 256 "$(basename "$DMG")" | tee "$(basename "$DMG").sha256" )

echo
echo "==> Done: $DMG"
echo
echo "This DMG is self-signed and NOT notarized. On first launch the user must"
echo "clear the quarantine flag once — document this in the release notes:"
echo "  • right-click Spitr.app → Open → Open, or"
echo "  • xattr -dr com.apple.quarantine /Applications/Spitr.app"
