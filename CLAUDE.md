# CLAUDE.md — Spitr

Fixierte Entscheidungen für dieses Projekt. Nicht erneut in Frage stellen, ohne dass
Jarek es explizit anstößt. Vollständiges Konzept: siehe [KONZEPT.md](KONZEPT.md).

## Was Spitr ist
Native macOS Voice-to-Text App: Taste halten → sprechen → loslassen → Text wird ins
fokussierte Fenster eingefügt. On-device, kostenlos, privat, ohne Cloud, ohne Abo.

## Arbeitsumgebung
- Entwicklung im **nativen Claude-Agenten in Xcode 26.5** (Settings → Intelligence).
- **Build / Run / Sign**: in Xcode. Headless-Build/Test: `xcodebuild -scheme Spitr build`
  bzw. `xcodebuild test`.
- SwiftUI-Previews dürfen zur visuellen Iteration genutzt werden.

## Architektur — Parnas-Module
- Jedes Modul kapselt **eine austauschbare Entscheidung** hinter einem Protokoll.
- Speech-Engine liegt hinter `protocol TranscriptionEngine`. Implementierungen:
  `AppleSpeechEngine` und `WhisperKitEngine`. **Nie** direkt gegen eine konkrete Engine
  programmieren — immer gegen das Protokoll.
- Modulgrenzen wie in KONZEPT.md (Core/ Services, Features/ UI). Services sind
  protokoll-getrieben und unit-testbar.

## Technische Leitplanken
- **Sprache/UI**: Swift + SwiftUI.
- **Engine-Default**: Apple `SpeechAnalyzer` (macOS 26) / `SFSpeechRecognizer` (13–15)
  auf Apple Silicon. **WhisperKit** als Fallback/Qualitätsoption (Intel/ältere Macs, beste
  DE-Genauigkeit). Auswahl über `EngineSelector` + manueller Override in Settings.
- **Hotkey**: `sindresorhus/KeyboardShortcuts` mit `onKeyDown`/`onKeyUp` (Hold-to-Talk).
- **Audio**: `AVAudioEngine`, 16 kHz mono.
- **Text-Insertion**: Clipboard + Cmd+V (CGEvent) mit **Snapshot/Restore** des
  Clipboards; AppleScript-Fallback für Nicht-QWERTY-Layouts (Vorbild VoiceInk
  `CursorPaster`).

## Harte Regeln (nicht verhandelbar)
- **Mikro nur während die Taste gehalten wird.** Kein Dauer-Listening, keine
  Auto-Aufnahme, keine VAD im MVP. `AudioEngine` startet am Key-Down, stoppt am Key-Up.
- **Keine Netzwerk-Calls im MVP.** Alles on-device. Keine Telemetrie, kein Analytics.
  *Bewusste Ausnahme (entschieden 2026-06-19):* WhisperKit darf sein Modell **einmalig**
  beim ersten Aktivieren herunterladen; danach läuft alles offline. Keine sonstigen Calls.
- **App-Sandbox AUS** (non-sandboxed) — nötig für Accessibility/Keystroke-Injection.
- **Permissions** minimal und einzeln erklärt: Mikrofon, Spracherkennung, Accessibility.
- **Signing**: „Sign to Run Locally" / Personal Team. Kein bezahlter Developer-Account
  voraussetzen.

## UI/UX
- Menüleisten-App (`LSUIElement = YES`), kein Dock-Icon. Status-Icon zeigt
  idle/recording/processing.
- Aufnahme-Overlay: randloses schwebendes Fenster mit audio-reaktiver Wellenform, nur
  während Aufnahme sichtbar. Schlank halten (SwiftUI Canvas), nicht GPU-schwer.
- Natives Settings-Fenster, sauberes macOS-Standard-Menü (About/Settings/Quit).

## Git-Commits
- Conventional Commits, **Subject-only**: `<type>: <description>`.
- Types: `feat`, `fix`, `refactor`, `test`, `docs`, `ci`, `build`, `infra`, `chore`.
- Imperativ, erste Zeile ≤ 72 Zeichen, kein Punkt am Ende, **kein Body**.
- **Kein `Co-Authored-By`-Trailer.**
- Commit nach jedem abgerundeten Stück aktiv anbieten.

## Kommunikation
- Antworten auf **Deutsch** (Code-Identifier englisch). Knapp, keine Floskeln.
