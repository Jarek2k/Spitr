# Spitr — Feature-Katalog

Lebende Liste aller umgesetzten Features. Quelle für die spätere Nutzer-Doku.
Bei jedem neuen Feature **hier eine Zeile ergänzen** (Status, kurze Nutzer-Sicht,
relevante Einstellung). Reihenfolge grob nach Nutzer-Reise.

Status: ✅ umgesetzt · 🧪 umgesetzt, real noch ungetestet · ➖ nicht relevant · 🔜 geplant

## Kern (Diktat-Durchstich)

| Feature | Status | Nutzer-Sicht | Einstellung |
|---|---|---|---|
| Hold-to-Talk | ✅ | Taste halten → sprechen → loslassen → Text wird ins fokussierte Feld eingefügt | Aufnahme-Taste (Allgemein) |
| On-device-Transkription | ✅ | Spracherkennung läuft lokal, ohne Cloud/Netz | Engine (Allgemein) |
| Apple-Speech-Engine | ✅ | Standard-Engine, kein Download | Engine = Apple Speech |
| WhisperKit-Engine | ✅ | Alternative Engine, lädt Modell einmalig, beste DE-Genauigkeit | Engine = WhisperKit, Modell |
| Aufnahme abbrechen (Esc) | ✅ | Esc während die Aufnahmetaste gehalten wird → nichts wird transkribiert/eingefügt; gegen Versprecher | — |
| Engine-Prewarm beim Start | ✅ | Modell wird beim App-Start im Hintergrund geladen, damit das erste Diktat nicht auf den Kaltstart wartet | — |
| Text-Insertion mit Clipboard-Restore | 🧪 | Einfügen via Cmd+V; Zwischenablage wird vorher gesichert und danach wiederhergestellt | — |
| Intelligente Leerzeichen | ✅ | Fasst doppelte Leerzeichen zusammen + setzt bei Bedarf ein Leerzeichen vor den Text (Kontext via Accessibility; entfällt in Electron); abschaltbar | Toggle (Allgemein) |
| AppleScript-Fallback (Nicht-QWERTY) | ➖ | Sonderfall für Nicht-QWERTY-Layouts (Dvorak/AZERTY); bei QWERTZ nie aktiv → für Jareks Setup nicht relevant, nicht weiter verfolgt | — |

## Bedienung & Anzeige

| Feature | Status | Nutzer-Sicht | Einstellung |
|---|---|---|---|
| Menüleisten-App | ✅ | Lebt in der Menüleiste, kein Dock-Icon; Icon zeigt idle/recording/processing | — |
| Aufnahme-Overlay | ✅ | Schwebende Kapsel mit Mikro + Wellenform, nur während Aufnahme | — |
| Wellenform-Stil wählbar | ✅ | „Balken" (Canvas), „Strähnen" (Metal-Shader) oder „KITT" (rote LED-Voice-Box); erweiterbar | Wellenform (Allgemein) |
| App-Icon | ✅ | Eigenes Icon in About/Dock (systemseitige Anzeige korrekt erst in Release-Build) | — |
| Ton bei Aufnahmebereitschaft | ✅ | Kurzer Ton, sobald das Mikro wirklich aufnimmt (erster echter Buffer) — verhindert verlorenes erstes Wort; abschaltbar | Toggle (Allgemein) |

## Konfiguration

| Feature | Status | Nutzer-Sicht | Einstellung |
|---|---|---|---|
| Engine-Auswahl + Override | ✅ | Engine manuell wählbar; aktive Engine/Modell im Menü sichtbar | Engine (Allgemein) |
| WhisperKit-Modellwahl | ✅ | base / small / large-v3-turbo; Modell wird beim Umschalten vorgewärmt (alle drei verifiziert; large-v3-turbo brachte für DE keinen Vorteil) | Modell (Allgemein) |
| Sprachauswahl | ✅ | Erkennungssprache (DE/EN/…) | Sprache (Allgemein) |
| Konfigurierbare Aufnahme-Taste | ✅ | Hold-to-Talk-Taste umschaltbar (⌥/⌃; fn nur MacBook-Tastatur), persistiert | Aufnahme-Taste (Allgemein) |
| Mikrofon-Auswahl | ✅ | Eingabegerät wählbar; Systemstandard + Fallback | Mikrofon (Allgemein) |
| Beim Anmelden starten | ✅ | Autostart bei Login | Toggle (Allgemein) |
| Custom Vocabulary | ✅ | Eigennamen/Fachbegriffe als Bias (hilft oft, nicht garantiert — Engine-Grenze) | Vokabular-Tab |
| Personal Dictionary | ✅ | Wort-Ersetzungen nach der Erkennung (Erkannt → Ersetzung); abschaltbar, default aus | Wörterbuch-Tab |
| Diktat-History | ✅ | Lokale, löschbare Liste der letzten Transkripte; Hover-Aktionen; abschaltbar | Verlauf-Tab |
| Letztes Diktat erneut einfügen | ✅ | Globaler Hotkey (Standard ⌃⌥⌘V, in Einstellungen frei belegbar) + Menü-Aktion: letztes Diktat erneut ins fokussierte Feld einfügen (Rettung bei falschem Fokus); auch bei ausgeschalteter History | Erneut-einfügen-Kürzel (Allgemein) / Menü |
| Sprachbefehl-Modus | ✅ | Aufnahme-Taste **+ ⇧** → Gesprochenes wird als Befehl ausgeführt statt eingefügt | Befehle-Tab (Liste) |
| Pausieren | ✅ | Diktat pausieren/fortsetzen (Menü oder Sprachbefehl »pause«/»weiter«) | Menü |

## Datenschutz & Onboarding

| Feature | Status | Nutzer-Sicht | Einstellung |
|---|---|---|---|
| Permission-Onboarding | ✅ | Erststart erklärt Mikro / Spracherkennung / Accessibility einzeln | aus Menü „Einrichtung…" erneut öffenbar |
| Mikro nur bei gehaltener Taste | ✅ | Kein Dauer-Listening, keine Auto-Aufnahme | — |
| Keine Netzwerk-Calls | ✅ | Alles on-device (Ausnahme: WhisperKit-Modell einmalig) | — |

## Geplant (Auswahl)

| Feature | Status | Notiz |
|---|---|---|
| Schnell-Korrektur (Wörterbuch-Regel) | 🔜 | NSServices verworfen 2026-06-20: Dienste-Menü gibt es nur in nativen AppKit-Apps, NICHT in Electron/Chromium (VS Code, Claude Code, Browser) = Jareks Haupt-Workflow → kein Mehrwert. Falls je wieder: app-unabhängig über Spitrs History (Menü/Hotkey „letztes Diktat korrigieren"), nicht über die Ziel-App. |
| VAD / Stille-Trimmer | 🔜 | v3, regelkonform (nur aufgenommenes Audio trimmen) |
| Audio-Feedback: Stop-/Fertig-Sound | 🔜 | Ready-Ton ist da; optionaler Ton bei Aufnahme-Ende/Einfügen noch offen |
| Lokales LLM-Cleanup | 🔜 | v3, optional/abschaltbar |
