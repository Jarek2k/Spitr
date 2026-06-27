# Spitr — *Spit it Out*

**Native macOS voice-to-text. Hold a key, speak, release — your words are
pasted into the focused window.** Fully on-device, free, private. No cloud, no
subscription, no telemetry.

> **Beta (0.9.0).** Spitr works and is used daily, but it's a self-signed
> personal project, not a polished 1.0. Expect rough edges. See
> [known limitations](#known-limitations).

<!-- TODO: add a short screen recording of the overlay + paste here -->

## Why

I wanted to dictate to tools like Claude Code instead of typing. The existing
options are either cloud + subscription (Wispr Flow, Aqua Voice) or open-source
projects I didn't fully trust to run unsupervised. Spitr is the self-built
answer: full control over the code, no cost, everything local.

**Principles**

1. **Private by design** — nothing leaves the device, no telemetry.
2. **Never secretly listening** — the mic is live *only* while you physically
   hold the key.
3. **Lightweight** — good recognition without hogging the machine.
4. **Native macOS feel** — menu bar, settings, icon, clean design.

## How it works

Hold the trigger key → a floating overlay with a live waveform appears → speak →
release → the audio is transcribed on-device → the text is pasted into wherever
your cursor is (clipboard + ⌘V, with your clipboard saved and restored around
it). Hold the key **with ⇧** to speak a command (e.g. *pause*, *resume*) instead
of dictating.

Default trigger is the **right ⌥ (Option)** key — a modifier, so holding it
never types a character. Configurable in Settings.

## Features

A few highlights (full living list in [FEATURES.md](FEATURES.md)):

- **Hold-to-talk** dictation into any app, with an audio-reactive overlay.
- **Two engines:** Apple Speech (built in, no download) or **WhisperKit**
  (downloads a model once, best German accuracy). Switchable in Settings.
- **Voice isolation** — Apple's voice-processing I/O for noise suppression and
  echo cancellation; on by default, can be turned off in a quiet room.
- **Custom vocabulary** and a **personal dictionary** of fixed replacements.
- **History** of recent dictations (local, deletable) with one-tap "turn a
  misrecognition into a permanent rule."
- **Re-insert** the last dictation via a global hotkey (rescue for wrong focus).
- **Voice commands** (pause/resume, etc.) and a **diagnostics log** that never
  contains your dictated text.
- **Multilingual UI** (de/en/fr/es/it/pl), following the system language.

## Privacy

- **No network calls.** Everything runs on-device. The *only* exception:
  WhisperKit downloads its model file **once**, on first activation, then runs
  fully offline. Apple Speech needs no download at all.
- **No telemetry, no analytics.** None. Ever.
- **Mic only while the key is held.** No continuous listening, no auto-record,
  no voice activity detection.
- **Logs stay local and text-free.** Diagnostic logs under
  `~/Library/Logs/Spitr` record events, timings and errors — never your dictated
  text.

You can verify all of this in the source.

## Permissions

Spitr asks for three permissions, each explained individually during onboarding:

| Permission | Why |
|---|---|
| **Microphone** | To capture audio while you hold the key. |
| **Speech Recognition** | For Apple's on-device transcription. |
| **Accessibility** | To receive the global hold-to-talk key and to paste text into other apps via synthesized ⌘V. |

**Why the app sandbox is off:** pasting into arbitrary apps (synthesized
keystrokes) and receiving a global hotkey are fundamentally incompatible with
the macOS App Sandbox. Spitr therefore ships **non-sandboxed**. This is a
deliberate, necessary trade-off for a tool that types into other apps — and the
reason "nothing leaves the device" is worth verifying in the code.

## Install

### Option A — download the DMG (self-signed beta)

Grab the latest DMG from the [Releases](../../releases) page and drag Spitr to
Applications.

Because this is a **self-signed beta without Apple notarization**, Gatekeeper
will quarantine it on first launch. Clear it once:

- **Right-click** `Spitr.app` → **Open** → **Open** in the dialog, **or**
- run:

  ```sh
  xattr -dr com.apple.quarantine /Applications/Spitr.app
  ```

Verify the download against the `SHA-256` published with the release:

```sh
shasum -a 256 Spitr-0.9.0.dmg
```

### Option B — build from source

Requires **macOS 26+** and **Xcode 26+** on Apple Silicon.

1. Clone the repo and open `Spitr.xcodeproj`.
2. Select the **Spitr** target → **Signing & Capabilities** → set **Team** to
   your Personal Team (or "Sign to Run Locally").
3. Build & run (⌘R). No paid Apple Developer account required.

```sh
xcodebuild -scheme Spitr build
xcodebuild test
```

`⌘R` produces an unoptimized **Debug** build under `DerivedData` — fine for
hacking, but heavier (slower, chattier logging) than a release build. For daily
use, build an optimized **Release** and install it like a real app:

```sh
Scripts/build_dmg.sh                 # Release build, locally signed, → dist/Spitr-<version>.dmg
```

Open the DMG, drag `Spitr.app` to `/Applications`, then clear the quarantine
flag once (same as Option A):

```sh
xattr -dr com.apple.quarantine /Applications/Spitr.app
```

This needs no paid Apple Developer account — it uses the same "Sign to Run
Locally" / Personal Team signing as `⌘R`, and the result runs indefinitely on
the machine that built it. (A quick `xcodebuild -scheme Spitr -configuration
Release build` also gives you an optimized binary without packaging a DMG.)

## Choosing an engine

- **Apple Speech** (default) — no download, low resource use, good for most
  dictation.
- **WhisperKit** — downloads a model once (`base` / `small` / `large-v3`), runs
  on the Neural Engine, and tends to give the best German accuracy. Larger
  models didn't measurably help German in testing; `base`/`small` are the sweet
  spot. Pick it in Settings → General.

## Known limitations

- **macOS 26+ only.** Spitr targets the current macOS and is not tested on
  earlier versions. WhisperKit is offered as a *quality* option, not a
  compatibility fallback.
- **Bluetooth mics (e.g. AirPods) are not supported as input** — macOS HFP/SCO
  doesn't start reliably for capture. Built-in and USB mics (e.g. Yeti) work.
  See [DEFERRED.md](DEFERRED.md).
- **Electron apps** (and other non-native targets): system-level text
  integrations like the Services menu don't apply there. Spitr's clipboard-paste
  path still works; the history-based correction flow is the app-independent fix.
- **Self-signed, not notarized** — hence the Gatekeeper step above.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The scope is intentionally small and the
fixed design decisions live in [CLAUDE.md](CLAUDE.md).

## Third-party code

See [THIRD_PARTY.md](THIRD_PARTY.md) — WhisperKit (MIT) and swift-argument-parser
(Apache-2.0).

## License

[MIT](LICENSE) © 2026 Jarek
