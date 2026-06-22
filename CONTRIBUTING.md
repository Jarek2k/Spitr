# Contributing to Spitr

Spitr is a personal project shared as open source. Issues and pull requests are
welcome, but please keep in mind that the scope is deliberately small (see the
non-goals in the [README](README.md)) and the design decisions in
[CLAUDE.md](CLAUDE.md) are fixed unless there's a strong reason to revisit them.

## Building

Requires **macOS 26+** and **Xcode 26+**. Open `Spitr.xcodeproj`, set the
signing team to your Personal Team / "Sign to Run Locally", then build and run.
No paid Apple Developer account is needed. See the README for details.

```sh
xcodebuild -scheme Spitr build      # build
xcodebuild test                     # run the test suite
```

## Ground rules

These are non-negotiable and predate any contribution (they're why the app
exists):

- **No network calls.** Everything is on-device. The only exception is
  WhisperKit downloading its model once on first activation. No telemetry, no
  analytics, ever.
- **Mic only while the key is held.** No continuous listening, no auto-record,
  no VAD.
- **No paid-account assumptions.** Local "Sign to Run Locally" signing must keep
  working.
- **Privacy in logs.** Diagnostic logs never contain dictated text.

## Code style

- Swift + SwiftUI, native macOS feel.
- Services hide one swappable decision behind a protocol (Parnas modules). Never
  program against a concrete speech engine — always the `TranscriptionEngine`
  protocol.
- User-facing strings go through the String Catalog. Add new strings to
  `Scripts/gen_localization.py` and run it; `Scripts/check_localization.py` and
  the localization tests gate this.

## Commits

Conventional Commits, **subject only**:

```
<type>: <description>
```

- Types: `feat`, `fix`, `refactor`, `test`, `docs`, `ci`, `build`, `infra`, `chore`
- Imperative mood ("add", "fix", "update"), first line ≤ 72 chars, no trailing
  period, no body, no `Co-Authored-By` trailer.

Example: `feat: add weekly plan builder view`
