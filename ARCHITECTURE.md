# Architecture

A short map of the codebase so a new contributor can find their way. For the
fixed product decisions (what Spitr is and isn't), see [CLAUDE.md](CLAUDE.md);
for the user-facing pitch, see the [README](README.md).

## The one idea

Spitr is built from **Parnas modules**: each `Core/` service hides exactly one
*changeable decision* behind a protocol, so the rest of the app never depends on
how that decision is currently made. The clearest example is the speech engine —
callers only ever see `TranscriptionEngine`, never `AppleSpeechEngine` or
`WhisperKitEngine`. Swapping or adding an engine touches one folder.

The app is a non-sandboxed menu-bar app (`LSUIElement`, no Dock icon). It has no
main window; the only transient UI is a floating recording overlay.

## Layout

```
Spitr/
├─ SpitrApp.swift          App entry: MenuBarExtra, AppDelegate, dependency wiring
├─ Core/                   Protocol-driven, UI-free, unit-testable services
│  ├─ Audio/               AudioCaptureService (AVAudioEngine, 16 kHz mono,
│  │                       live only while the key is held), AudioDeviceService
│  ├─ Input/               HotkeyService — dependency-free NSEvent monitors,
│  │                       hold-to-talk on a modifier key (needs Accessibility)
│  ├─ Transcription/       TranscriptionEngine (protocol) + AppleSpeechEngine,
│  │                       WhisperKitEngine, EngineSelector
│  ├─ Text/                TextInsertionService — clipboard + ⌘V via CGEvent with
│  │                       snapshot/restore; intelligent spacing; replacements
│  ├─ Permissions/         PermissionService — mic / speech / accessibility
│  ├─ Settings/            SettingsStore and the per-feature stores it owns
│  ├─ Diagnostics/         LogStore — rotating, text-free local log file
│  ├─ Feedback/            short start/stop recording cues
│  └─ Theme/               SpitrTheme (brand colours)
└─ Features/               SwiftUI surfaces; depend on Core via protocols
   ├─ Recording/           RecordingController — the state machine that drives
   │                       a capture (idle → recording → transcribing → inserting)
   ├─ Overlay/             RecordingOverlay + the selectable waveform views
   ├─ MenuBar/             status icon and quick menu/popover
   ├─ Settings/            settings window and Settings/Tabs/ (General, Vocabulary,
   │                       Dictionary, Commands, History, Diagnostics)
   ├─ Onboarding/          first-run permission walkthrough
   └─ Help/                on-device quick help
```

## The exchangeable engine

```swift
protocol TranscriptionEngine {
    var id: String { get }
    var isAvailable: Bool { get }                 // hardware / OS check
    func prepare() async throws                   // prewarm / load model
    func transcribe(_ audio: AudioBuffer, locale: Locale, vocabulary: [String]) async throws -> String
}
```

`EngineSelector` defaults to **`AppleSpeechEngine`** (`SFSpeechRecognizer`,
on-device, zero download). **`WhisperKitEngine`** is a manually selectable
*quality* option (best German accuracy, runs on the Neural Engine) — not a
compatibility fallback, since Spitr is macOS-26-only. The choice is a Settings
override; nothing else in the app knows which engine is active.

## Data flow of one dictation

```
key down → AudioCaptureService.start() + overlay shown
         → samples stream in (16 kHz mono)
key up   → engine.transcribe(buffer) → text
         → TextInsertionService.insert(text)  (clipboard saved & restored)
         → overlay hidden
```

`RecordingController` owns this sequence and the recording state machine;
everything else reacts to its published state.

## Constraints worth knowing before you change things

- **Mic only while the key is held.** No continuous listening, no VAD. Capture
  starts on key-down and stops on key-up — keep it that way.
- **No network calls.** Everything is on-device. The single exception is
  WhisperKit downloading its model once on first activation.
- **The app sandbox is off** — synthesizing keystrokes and receiving a global
  hotkey are incompatible with it. This is deliberate and load-bearing.
- **macOS 26+, Apple Silicon only.** No back-deployment guards are expected.

## Localization

All user-facing strings live in `Localizable.xcstrings` / `InfoPlist.xcstrings`,
generated from a single source list in `Scripts/gen_localization.py` (source
German, translated to en/fr/es/it/pl). `LocalizationCatalogTests` and
`Scripts/check_localization.py` fail the build if a visible string is missing a
translation. Add UI strings via the generator, not by hand.

## Where to start reading

- `SpitrApp.swift` — how everything is wired together.
- `Features/Recording/RecordingController.swift` — the heart of a capture.
- `Core/Transcription/` — the protocol seam most contributions touch.
- Tests live in `SpitrTests/`; run them with `xcodebuild test -scheme Spitr`.
