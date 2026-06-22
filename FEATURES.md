# Spitr — Feature-Katalog

Lebende Liste aller umgesetzten Features. Quelle für die spätere Nutzer-Doku.
Bei jedem neuen Feature **hier eine Zeile ergänzen** (Status, kurze Nutzer-Sicht,
relevante Einstellung). Reihenfolge grob nach Nutzer-Reise.

Status: ✅ umgesetzt · 🧪 umgesetzt, real noch ungetestet · ➖ nicht relevant · 🔜 geplant

## Kern (Spracheingabe-Durchstich)

| Feature | Status | Nutzer-Sicht | Einstellung |
|---|---|---|---|
| Hold-to-Talk | ✅ | Taste halten → sprechen → loslassen → Text wird ins fokussierte Feld eingefügt | Aufnahme-Taste (Allgemein) |
| On-device-Transkription | ✅ | Spracherkennung läuft lokal, ohne Cloud/Netz | Engine (Allgemein) |
| Apple-Speech-Engine | ✅ | Standard-Engine, kein Download | Engine = Apple Speech |
| WhisperKit-Engine | ✅ | Alternative Engine, lädt Modell einmalig, beste DE-Genauigkeit | Engine = WhisperKit, Modell |
| Aufnahme abbrechen (Esc) | ✅ | Esc während die Aufnahmetaste gehalten wird → nichts wird transkribiert/eingefügt; gegen Versprecher | — |
| Engine-Prewarm beim Start | ✅ | Modell wird beim App-Start im Hintergrund geladen, damit die erste Spracheingabe nicht auf den Kaltstart wartet | — |
| Text-Insertion mit Clipboard-Restore | ✅ | Einfügen via Cmd+V; Zwischenablage wird vorher gesichert und danach wiederhergestellt | — |
| Intelligente Leerzeichen | ✅ | Fasst doppelte Leerzeichen zusammen + setzt bei Bedarf ein Leerzeichen vor den Text (Kontext via Accessibility; entfällt in Electron); abschaltbar | Toggle (Allgemein) |
| AppleScript-Fallback (Nicht-QWERTY) | ➖ | Sonderfall für Nicht-QWERTY-Layouts (Dvorak/AZERTY); bei QWERTZ nie aktiv → für Jareks Setup nicht relevant, nicht weiter verfolgt | — |

## Bedienung & Anzeige

| Feature | Status | Nutzer-Sicht | Einstellung |
|---|---|---|---|
| Menüleisten-App | ✅ | Lebt in der Menüleiste, kein Dock-Icon; Icon zeigt idle/recording/processing | — |
| Natives Menüleisten-Popover | ✅ | Klick aufs Symbol öffnet ein Popover, dessen Einträge wie native macOS-Menüpunkte beim Überfahren highlighten (Accent-Fill, weiße Schrift); „Beenden" → „Spitr beenden" | — |
| Aufnahme-Overlay | ✅ | Schwebende Kapsel mit Mikro + Wellenform, nur während Aufnahme | — |
| Wellenform-Stil wählbar | ✅ | „Balken" (Canvas), „Strähnen" (Metal-Shader) oder „KITT" (rote LED-Voice-Box); erweiterbar | Wellenform (Allgemein) |
| App-Icon | ✅ | Eigenes Icon in About/Dock (systemseitige Anzeige korrekt erst in Release-Build) | — |
| Über-Spitr-Panel | ✅ | Icon, Version + Build, Copyright und kurze Beschreibung (statt nur Icon/Version) | Menü „Über Spitr" |
| Hilfe-Menü | ✅ | „Spitr-Hilfe" (⌘?) öffnet on-device Kurzanleitung (Diktieren, Befehle, Vokabular/Wörterbuch, Engines, Datenschutz); ersetzt den toten Standard-Help-Eintrag. ⌘? öffnet direkt (macOS-Hilfe-Suchfeld wird abgefangen) | Menü „Hilfe" |
| Fenster mit Esc schließen | ✅ | Esc schließt Einstellungen, Hilfe, Einrichtung und das Menüleisten-Popover | — |
| Mehrsprachige Oberfläche | ✅ | Komplette App **und** Standard-macOS-Menüs folgen der Systemsprache: Deutsch, Englisch, Französisch, Spanisch, Italienisch, Polnisch (Quellsprache DE, Fallback EN). Per-App-Sprache via macOS-Override möglich. Übersetzungen aus `Scripts/gen_localization.py`, abgesichert durch Tests gegen vergessene Strings | — |
| Aufgeräumtes App-Menü | ✅ | „Dienste"-Untermenü entfernt (Spitr bietet keine an); App-Menü auf Sinnvolles reduziert | — |
| Ton bei Aufnahmebereitschaft | ✅ | Kurzer Ton, sobald das Mikro wirklich aufnimmt (erster echter Buffer) — verhindert verlorenes erstes Wort; abschaltbar | Toggle (Allgemein) |
| Ton bei Aufnahme-Ende | 🧪 | Kurzer abgesetzter Ton (zwei absteigende Noten), sobald der Text eingefügt wurde — markiert das Ende der Umwandlung, hilft bei langsameren Engines; eigener, separat abschaltbarer Toggle | Toggle (Allgemein) |

## Konfiguration

| Feature | Status | Nutzer-Sicht | Einstellung |
|---|---|---|---|
| Vereinheitlichte Einstellungen | ✅ | Alle Tabs (Allgemein, Vokabular, Wörterbuch, Befehle, Verlauf, Diagnose) im konsistenten nativen „grouped"-Form-Stil mit Abschnitten + Fußnoten statt heterogener Layouts | — |
| Engine-Auswahl + Override | ✅ | Engine manuell wählbar; aktive Engine/Modell im Menü sichtbar | Engine (Allgemein) |
| WhisperKit-Modellwahl | ✅ | base / small / large-v3; Modell wird beim Umschalten vorgewärmt (alle drei verifiziert; große Modelle brachten für DE keinen Vorteil). large-v3-turbo entfernt: löste in WhisperKits Repo nicht auf → jede Transkription schlug fehl | Modell (Allgemein) |
| Sprachauswahl | ✅ | Erkennungssprache (DE/EN/…) | Sprache (Allgemein) |
| Konfigurierbare Aufnahme-Taste | ✅ | Hold-to-Talk-Taste umschaltbar (⌥/⌃; fn nur MacBook-Tastatur), persistiert | Aufnahme-Taste (Allgemein) |
| Mikrofon-Auswahl | ✅ | Eingabegerät wählbar; Systemstandard + Fallback. Eingebautes + USB-Mikros (z. B. Yeti) verifiziert; **Bluetooth-Mikros (AirPods) als Eingang nicht unterstützt** (macOS-HFP/SCO startet nicht zuverlässig — siehe DEFERRED) | Mikrofon (Allgemein) |
| Sprachisolierung | 🧪 | Apples Voice-Processing-I/O (Rauschunterdrückung, Echo-Cancellation, automatische Pegelanpassung) auf dem Mikrofon-Eingang — gegen Nuscheln + Hintergrundgeräusche (z. B. TV); default an, in sehr ruhiger Umgebung abschaltbar | Sprachisolierung (Allgemein) |
| Beim Anmelden starten | ✅ | Autostart bei Login | Toggle (Allgemein) |
| Custom Vocabulary | ✅ | Eigennamen/Fachbegriffe als Bias (hilft oft, nicht garantiert — Engine-Grenze) | Vokabular-Tab |
| Personal Dictionary | ✅ | Wort-Ersetzungen nach der Erkennung (Erkannt → Ersetzung); abschaltbar, default aus | Wörterbuch-Tab |
| Spracheingabe-Verlauf | ✅ | Lokale, löschbare Liste der letzten Transkripte; Hover-Aktionen; abschaltbar | Verlauf-Tab |
| Spracheingabe-Korrektur | 🧪 | Falsch erkanntes Wort fix zur Wörterbuch-Regel machen (Verlauf-Tab Hover/Kontextmenü oder Menü „Letzte Spracheingabe korrigieren…"): falsches Wort antippen → Ersetzung eingeben → „Regel sichern". Wörterbuch wird dabei aktiviert, der betroffene Eintrag gleich mit korrigiert; die Regel gilt künftig automatisch. App-unabhängig über den Verlauf — funktioniert auch dort, wo ein Dienste-Menü nicht greift (Electron) | Verlauf-Tab / Menü |
| Letzte Spracheingabe erneut einfügen | ✅ | Globaler Hotkey (Standard ⌃⌥⌘V, in Einstellungen frei belegbar) + Menü-Aktion: letzte Spracheingabe erneut ins fokussierte Feld einfügen (Rettung bei falschem Fokus); auch bei ausgeschaltetem Verlauf | Erneut-einfügen-Kürzel (Allgemein) / Menü |
| Sprachbefehl-Modus | ✅ | Aufnahme-Taste **+ ⇧** → Gesprochenes wird als Befehl ausgeführt statt eingefügt | Befehle-Tab (Liste) |
| Pausieren | ✅ | Spracheingabe pausieren/fortsetzen (Menü oder Sprachbefehl »pause«/»weiter«) | Menü |

## Datenschutz & Onboarding

| Feature | Status | Nutzer-Sicht | Einstellung |
|---|---|---|---|
| Permission-Onboarding | ✅ | Erststart erklärt Mikro / Spracherkennung / Accessibility einzeln | aus Menü „Einrichtung…" erneut öffenbar |
| Mikro nur bei gehaltener Taste | ✅ | Kein Dauer-Listening, keine Auto-Aufnahme | — |
| Keine Netzwerk-Calls | ✅ | Alles on-device (Ausnahme: WhisperKit-Modell einmalig) | — |
| Diagnose-Protokoll | 🧪 | Persistentes, rotierendes Log unter `~/Library/Logs/Spitr` (Ereignisse, Zeiten, Fehler — **nie** diktierter Text); per Schalter „Ausführliches Protokoll" zusätzlich Speicher-/Thread-Samples zum Leck-Aufspüren über Tage. Bleibt komplett lokal | Diagnose-Tab |

## Geplant (Auswahl)

Aktuell keine offenen MVP-Features mehr eingeplant. Zurückgestellte/geparkte
Punkte (Medien-Pause, UI-Polish) stehen in [DEFERRED.md](DEFERRED.md).
