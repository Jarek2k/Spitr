#!/usr/bin/env bash
#
# release.sh — cut a Spitr release: bump version, push, trigger the CI release.
#
# The actual build/sign/publish happens in GitHub Actions (.github/workflows/
# release.yml): it runs the unit tests, builds an ad-hoc-signed DMG and publishes
# a pre-release with the versioned DMG + SHA-256. This script is only the local
# entry point that gets a clean commit onto main and kicks off that workflow.
#
# Usage:
#   Scripts/release.sh 0.9.1
#
# Prerequisites: `gh` authenticated, working tree clean, HEAD pushed to main.
#
set -euo pipefail

VERSION="${1:-}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW="release.yml"
BRANCH="main"

cd "$REPO"

if [[ -z "$VERSION" ]]; then
    echo "usage: Scripts/release.sh <version>   e.g. 0.9.1" >&2
    exit 2
fi

# --- Preconditions ----------------------------------------------------------
if [[ -n "$(git status --porcelain)" ]]; then
    echo "error: working tree is not clean — commit or stash first." >&2
    exit 1
fi

git fetch --quiet origin "$BRANCH"
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$BRANCH")" ]]; then
    echo "error: HEAD is not in sync with origin/$BRANCH — push or pull first." >&2
    exit 1
fi

# --- Bump + push ------------------------------------------------------------
Scripts/bump_version.sh "$VERSION"

if [[ -n "$(git status --porcelain)" ]]; then
    git commit -aqm "build: bump version to $VERSION"
    git push --quiet origin "$BRANCH"
    echo "==> Pushed version bump to origin/$BRANCH."
else
    echo "==> No version change to commit (already $VERSION)."
fi

# --- Trigger the release workflow -------------------------------------------
# Remember the newest run id so we can wait for the *new* one to appear rather
# than watching a stale run (workflow_dispatch returns no id of its own).
prev="$(gh run list --workflow "$WORKFLOW" --limit 1 --json databaseId \
        --jq '.[0].databaseId // 0')"

echo "==> Dispatching $WORKFLOW for v$VERSION…"
gh workflow run "$WORKFLOW" -f publish_release=true -f prerelease=true

echo "==> Waiting for the run to register…"
run_id=""
for _ in $(seq 1 30); do
    run_id="$(gh run list --workflow "$WORKFLOW" --limit 1 --json databaseId \
              --jq '.[0].databaseId // 0')"
    [[ "$run_id" != "0" && "$run_id" != "$prev" ]] && break
    run_id=""
    sleep 2
done

if [[ -z "$run_id" ]]; then
    echo "warning: could not find the new run — check 'gh run list'." >&2
    exit 1
fi

gh run watch "$run_id" --exit-status

echo
echo "==> Release v$VERSION published:"
gh release view "v$VERSION" --json url,assets \
    --jq '"  " + .url, (.assets[] | "  asset: " + .name)'
