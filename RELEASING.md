# Releasing Spitr

Releases are built and published by GitHub Actions, not on a developer machine.
One command bumps the version, pushes it, and triggers the workflow that tests,
builds and publishes the DMG.

## Prerequisites

- [`gh`](https://cli.github.com) authenticated (`gh auth status`).
- A clean working tree with `main` pushed to `origin` — the script refuses
  otherwise, because the workflow always builds `origin/main`.

## Cut a release

```sh
Scripts/release.sh 0.9.1
```

This will:

1. Verify the tree is clean and `HEAD == origin/main`.
2. Bump `MARKETING_VERSION` to `0.9.1` (`Scripts/bump_version.sh`), commit
   `build: bump version to 0.9.1`, and push.
3. Dispatch [`.github/workflows/release.yml`](.github/workflows/release.yml) and
   stream the run until it finishes.

The workflow runs the unit tests **first**; only if they pass does it build an
ad-hoc-signed DMG and publish a GitHub **pre-release** `v0.9.1` with
`Spitr-0.9.1.dmg` and its `.sha256`.

## Versioning

`MAJOR.MINOR.PATCH`. While in beta, bump the **patch** (`0.9.0 → 0.9.1 → …`) and
keep every release a **pre-release**. The first stable cut is `1.0.0` (drop the
pre-release flag in the workflow dispatch inputs).

The tag and release name are derived from the built app's
`CFBundleShortVersionString`, so the version in the project is the single source
of truth — never tag by hand.

## Signing & notarization

No paid Apple Developer account is used, so the DMG is **ad-hoc signed and not
notarized**. On first launch macOS quarantines it; users clear it once
(`xattr -dr com.apple.quarantine /Applications/Spitr.app`). A side effect of
ad-hoc signing: the code identity changes every build, so macOS may re-prompt for
Accessibility / Microphone permission after an update. For a stable local install
on your own machine, build with `Scripts/build_dmg.sh` (Personal-Team signed)
instead.

## Public download link

The [landing page](https://github.com/Jarek2k/Spitr-Web) resolves the newest
non-draft release's DMG via the GitHub API. That only works for anonymous
visitors once `Jarek2k/Spitr` is **public** — until then the API returns 404 for
unauthenticated requests. Make the repo public before relying on the website
download button.
