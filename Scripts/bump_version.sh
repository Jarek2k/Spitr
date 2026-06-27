#!/usr/bin/env bash
#
# bump_version.sh — set the app's marketing version (CFBundleShortVersionString).
#
# Updates MARKETING_VERSION across every build config in the Xcode project so the
# built app, the DMG name and the release tag all agree. Build number
# (CURRENT_PROJECT_VERSION) is left untouched — the pre-1.0 betas track the
# marketing version alone.
#
# Usage:
#   Scripts/bump_version.sh 0.9.1
#
set -euo pipefail

VERSION="${1:-}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ="$REPO/Spitr.xcodeproj/project.pbxproj"

if [[ -z "$VERSION" ]]; then
    echo "usage: Scripts/bump_version.sh <version>   e.g. 0.9.1" >&2
    exit 2
fi

# Accept MAJOR.MINOR.PATCH (the scheme this project ships). Reject anything else
# early so a typo can't produce a bogus tag downstream.
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: '$VERSION' is not a MAJOR.MINOR.PATCH version" >&2
    exit 2
fi

OLD="$(grep -m1 -E 'MARKETING_VERSION = ' "$PBXPROJ" | sed -E 's/.*= (.*);/\1/')"

if [[ "$OLD" == "$VERSION" ]]; then
    echo "==> MARKETING_VERSION already $VERSION — nothing to do."
    exit 0
fi

# Every config carries a literal `MARKETING_VERSION = X;` line, so a direct
# rewrite is deterministic. (agvtool is skipped: it no-ops on this project's
# build-setting layout — it has no apple-generic versioning system configured.)
sed -i '' -E "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $VERSION;/" "$PBXPROJ"

# Verify it took everywhere (sed silently matches nothing if the layout drifts).
if grep -E 'MARKETING_VERSION = ' "$PBXPROJ" | grep -qv "= $VERSION;"; then
    echo "error: some MARKETING_VERSION entries did not update to $VERSION" >&2
    exit 1
fi

echo "==> MARKETING_VERSION: $OLD -> $VERSION"
