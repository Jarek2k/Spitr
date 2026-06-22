# Spitr — „Spit it Out"

Native macOS Voice-to-Text App. **Taste halten → sprechen → loslassen → Text erscheint
im fokussierten Fenster.** Komplett on-device, kostenlos, privat, ohne Cloud, ohne Abo.

---

## Vision & Motivation

Spracheingaben (z.B. für Claude Code) sprechen statt tippen. Bestehende Tools sind
entweder Cloud + Abo (Wispr Flow, Aqua Voice) oder Open-Source, denen man wegen
möglicher KI-generierter Schadsoftware nicht traut. Spitr ist die selbstgebaute Antwort:
volle Kontrolle über den Code, kein Geld, alles lokal.

**Leitprinzipien**
1. **Privat by design** — nichts verlässt das Gerät, keine Telemetrie.
2. **Nie heimlich** — Mikro nur aktiv, solange die Taste physisch gehalten wird.
3. **Leichtgewichtig** — gute Erkennung bei wenig Ressourcen; läuft auch auf älteren Macs.
4. **Native macOS-Anmutung** — Menüleiste, Settings, Icon, sauberes Design.

---

## Zielplattform

- **macOS 26+ only** (Apple Silicon). Bewusst auf das aktuelle macOS festgelegt; ältere
  Versionen werden nicht unterstützt. Windows ggf. später als eigene App.
- Entwicklung & Nutzung **kostenlos**: kein bezahlter Apple-Developer-Account. Signieren
  via „Sign to Run Locally" (auf macOS dauerhaft gültig — der 7-Tage-Ablauf gilt nur für
  iOS). $99/Jahr erst nötig, wenn man die App breit an Fremde verteilen will
  (Notarization).

---

## Architektur (Parnas-Module — Geheimnisprinzip)

Jedes Modul kapselt **eine austauschbare Entscheidung** hinter einem stabilen Protokoll.
Dadurch ist „welche Speech-Engine" ein Implementierungsdetail.

```
Spitr/
├─ App/                 SpitrApp (MenuBarExtra), AppDelegate, DI-Wiring
├─ Core/
│  ├─ HotkeyService        ── KeyboardShortcuts: Hold-to-Talk, Key-Down/Up → Events
│  ├─ AudioCaptureService  ── AVAudioEngine 16kHz mono; nur aktiv während Taste hält
│  ├─ TranscriptionEngine  ── PROTOKOLL (Geheimnis: welche Engine)
│  │     ├─ AppleSpeechEngine   (SpeechAnalyzer macOS 26+, SFSpeechRecognizer 13–15)
│  │     └─ WhisperKitEngine    (Modell-Download/-Auswahl, ANE)
│  ├─ TextInsertionService ── Clipboard + Cmd+V (CGEvent) + Snapshot/Restore;
│  │                           AppleScript-Fallback (Vorbild: VoiceInk CursorPaster)
│  ├─ PermissionService    ── Mic / Speech / Accessibility prüfen & anfragen
│  └─ ModelManager         ── Whisper-Modelle laden/cachen/auswählen
├─ Features/
│  ├─ Recording          ── State-Machine: idle→recording→transcribing→inserting
│  ├─ Overlay            ── schwebendes Fenster mit Wellenform (SwiftUI Canvas)
│  ├─ MenuBar            ── Status-Icon + Schnellmenü
│  └─ Settings           ── Hotkey, Engine, Modell, Sprache, Mic-Auswahl
└─ Resources/           ── Icon, Assets
```

**Datenfluss (eine Aufnahme):**
Key-Down → `AudioCaptureService.start()` + Overlay an → Samples streamen → Key-Up →
`engine.transcribe(buffer)` → Text → `TextInsertionService.insert(text)` → Overlay aus.

**Engine-Protokoll (Kern der Austauschbarkeit):**
```swift
protocol TranscriptionEngine {
    var id: String { get }
    var isAvailable: Bool { get }            // Hardware/OS-Check
    func prepare() async throws              // Prewarm / Modell laden
    func transcribe(_ audio: AudioBuffer, locale: Locale) async throws -> String
}
```
`EngineSelector`-Default: `AppleSpeechEngine` (zero Download). `WhisperKitEngine` als
manuell wählbare **Qualitätsoption** (beste DE-Genauigkeit) — kein Kompatibilitäts-Fallback,
da macOS-26-only. Manuelle Override in Settings.

---

## Technische Eckpfeiler

| Aspekt | Entscheidung | Grund |
|---|---|---|
| Sprache/UI | Swift + SwiftUI | nativ, performant |
| Speech (default) | Apple `SFSpeechRecognizer` (on-device) | kein Download, minimaler Verbrauch |
| Speech (Qualitätsoption) | **WhisperKit** (SPM) | beste DE-Genauigkeit, ANE-beschleunigt; manuell wählbar, kein Fallback |
| Hotkey | dependency-free `NSEvent`-Monitore (`HotkeyService`) | Hold-to-Talk per Modifier; braucht Accessibility |
| Audio | `AVAudioEngine`, 16 kHz mono | Standard-Input für Whisper/Apple |
| Text-Insertion | Clipboard + Cmd+V (CGEvent), Snapshot/Restore; AppleScript-Fallback | robustester Weg, auch in Terminal/Electron (Vorbild VoiceInk) |
| Sandbox | **AUS** (non-sandboxed) | Accessibility/Keystroke-Injection unvereinbar mit Sandbox |
| Permissions | Mic, Speech, Accessibility | einzeln erklärt im Onboarding |

---

## MVP-Scope (Durchstich)

Ziel: gedrückte Taste → sprechen → loslassen → Text im fokussierten Feld.

- [ ] Engine-Protokoll + **AppleSpeechEngine** (erste lauffähige Engine)
- [ ] **AudioCaptureService** (AVAudioEngine, 16 kHz mono, nur während Hold)
- [ ] **HotkeyService** Hold-to-Talk (Default z.B. ⌥-Space, in Settings änderbar)
- [ ] **TextInsertionService** Clipboard + Cmd+V mit Snapshot/Restore
- [ ] **MenuBarExtra** mit Status-Icon (idle/recording/processing)
- [ ] **Overlay** mit audio-reaktiver Wellenform (schlank, SwiftUI Canvas)
- [ ] **PermissionService** + Onboarding (Mic → Speech → Accessibility, mit Erklärtext)
- [ ] **WhisperKitEngine** + 1 auto-geladenes Default-Modell + Engine-Auswahl (Abschluss)
- [ ] **Settings-Fenster** (Hotkey, Engine, Sprache DE/EN, Mikrofon)
- [ ] App-Icon + Menüleisten-Icon

**Bewusst NICHT im MVP:** LLM-Cleanup, History, app-spezifische Modes, VAD,
Cloud-Engines, Streaming-Live-Preview, Auto-Updates.

---

## Roadmap

**v2 — Komfort & Robustheit** ✅ (weitgehend umgesetzt)
- AppleScript-Paste-Fallback (Nicht-QWERTY-Layouts) ✅
- Modell-Manager-UI (base / small / large-v3-turbo-q5) ✅
- Spracheingabe-Verlauf (lokal, löschbar) ✅
- Medien-Pause während Aufnahme ✅
- Personal Dictionary / Wort-Ersetzungen ✅ (default aus)
- Launch-at-Login ✅
- Wählbare Wellenform-Stile (Signal reaktiv/randlos/Kapsel, Balken, KITT) ✅
- Audio-Feedback (Start/Stop-Sound) → auf v3 verschoben
- Auto-Spracherkennung → offen

**Später**
- AppIntents/Shortcuts, Stats, Cloud-Engine-Option (opt-in), Parakeet (Low-Latency, nur
  Apple Silicon), eigene Windows-App.

---

## UI / UX

- **Menüleisten-App** (`LSUIElement`), kein Dock-Icon; Status-Icon idle/recording/processing.
- **Overlay**: randloses, schwebendes `NSPanel`, audio-reaktive Wellenform, nur während
  Aufnahme sichtbar.
- **Settings**: natives `Settings`-Fenster (Tabs: General, Engine, Hotkey, Privacy).
- **Menü-Standard**: About, Settings…, Quit.
- **Onboarding**: 3 Permission-Schritte mit Klartext-Begründung.

---

## Sicherheits- & Datenschutzmodell

- Mikro **nur** während Taste gehalten — kein Dauer-Listening, keine VAD im MVP.
- Komplett **on-device**, **keine** Netzwerk-Calls im MVP (im Code verifizierbar).
- Clipboard vor Paste sichern, danach wiederherstellen.
- Keine Telemetrie. History (v2) lokal und löschbar.
- Minimal nötige Permissions, einzeln erklärt.

---

## Referenz-Projekte (Open Source, zum Abschauen)

- **VoiceInk** (GPLv3, Swift) — `CursorPaster.swift` ist das beste Vorbild für
  Text-Insertion; app-spezifische Modes, Personal Dictionary.
- **OpenSuperWhisper** (MIT, Swift) — whisper.cpp-Bridge, Single-Modifier-Hotkeys.
- **FluidVoice** (Swift) — engine-agnostisch, Write/Command-Mode.
- **Handy** (Rust/Tauri) — Silero-VAD, mehrstufige Insertion (Referenz-Architektur).
- **WhisperKit** (argmaxinc) — reines SPM, automatische ANE/GPU/CPU-Beschleunigung.
