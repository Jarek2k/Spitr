# Spitr — Zurückgestellte Features

Features, die **bewusst aus dem Code ausgebaut** oder vertagt wurden. Diese Liste
gehen wir am Ende, wenn das MVP komplett ist, gemeinsam noch einmal durch.
Anders als der „Geplant"-Abschnitt in [FEATURES.md](FEATURES.md): Hier liegt Zeug,
das wir schon gebaut hatten oder das an einer Plattform-Grenze hängt.

---

## Medien-Pause während der Aufnahme

**Wunsch:** Beim Aufnehmen laufende Wiedergabe (Spotify, Apple Music, YouTube)
automatisch kurz pausieren, danach fortsetzen — damit man nicht von Hand pausieren muss.

**Status:** am 2026-06-20 aus dem Code **ausgebaut** (war `MediaPlaybackController` +
Verdrahtung in `RecordingController`).

**Warum ausgebaut:** Die Umsetzung bridgte das private `MediaRemote`-Framework via
`dlopen`/`dlsym`. Auf macOS 26 verifiziert tot:

```
[media] MediaRemote bridged; media pause active   ← Symbole lösen auf, Bridging lebt
[media] nowPlaying isPlaying=false                 ← Spotify spielt, macOS meldet "nichts"
```

Apple hat ab **macOS 15.4** nicht das Symbol entfernt, sondern Dritt-Apps die
Now-Playing-**Daten** entzogen: `MRMediaRemoteGetNowPlayingApplicationIsPlaying`
antwortet, liefert aber immer `false`. Damit ist dieser Weg auf aktuellem macOS
nicht reaktivierbar.

### Lösungsweg für später (macOS): AppleScript direkt an die Player

Funktioniert auf macOS 26, weil es nicht über MediaRemote geht. Deckt **Spotify +
Apple Music** ab, **nicht** YouTube/Browser-Videos (dafür kein sauberer Weg mehr).

- Status abfragen, nur pausieren was lief, nachher gezielt fortsetzen:
  - Spotify: `tell application "Spotify" to player state` → `playing`/`paused`/`stopped`;
    bei `playing` → `pause`, merken; nach Aufnahme → `play`.
  - Apple Music: `tell application "Music" to player state` analog.
- Beide Player getrennt behandeln (einer kann laufen, der andere nicht).
- Nur ansprechen, wenn die App überhaupt läuft (kein Auto-Launch provozieren):
  vorher via `running` prüfen bzw. `osascript`-Fehler abfangen.
- Kosten: einmaliger **Automation-Permission-Prompt** (Apple Events) pro Ziel-App;
  `NSAppleEventsUsageDescription` in Info.plist nötig. Im Onboarding erwähnen.
- Implementierung: `NSAppleScript` oder `Process`/`osascript`; Aufruf am Key-Down
  (pause) und Key-Up (resume), analog zur alten Verdrahtung.

### Reaktivierungs-Trigger

- **Windows-Port** (ggf. geplant): Dort existiert die macOS-MediaRemote-Sperre nicht;
  Mediensteuerung läuft über andere APIs (z.B. `GlobalSystemMediaTransportControls`).
  Das Feature könnte dort regulär funktionieren — beim Port neu bewerten.
- Falls Apple Now-Playing für Dritt-Apps je wieder öffnet.

---

## UI-Polish (eigene Ausbaustufe, am Ende gebündelt)

Sammelpunkt für visuelles Feinschliff-Zeug, das wir bewusst nicht im MVP-Durchstich
machen, sondern in einer dedizierten Polish-Runde.

- **Neues, schöneres App-Icon gestalten.** Das aktuelle (blau-lila Squircle + Mikrofon)
  gefällt nicht. Nur die *Gestaltung* ist offen — das Asset ist vollständig und wird
  korrekt geladen.
  (Erledigt 2026-06-20: Das graue Gittermuster war **nicht** das Asset, sondern der
  macOS-LaunchServices-Icon-Cache, der für `.accessory`-Apps im „Über"-Panel/Dock einen
  Platzhalter liefert. Fix in `SpitrApp.swift`: „Über"-Panel via `CommandGroup(replacing:
  .appInfo)` + `orderFrontStandardAboutPanel` mit explizit übergebenem Icon; Dock-Icon
  via erneutes `applicationIconImage`-Setzen nach dem `.regular`-Wechsel.)
- **Wellenform-Stile feinschleifen oder reduzieren.** Alle drei (Balken, Strähnen,
  KITT) laufen technisch sauber (auch der Metal-Shader, kein Stitching-Crash), aber
  keiner überzeugt Jarek ästhetisch ganz. In der Polish-Runde entscheiden: welcher wird
  Default, welche werden nachpoliert, welche evtl. entfernt. (Favorit noch offen.)
- ~~**App-Menü (Apple-/Spitr-Menü) eindeutschen.**~~ *(2026-06-21 erledigt.)* Das eigene
  Popover war schon deutsch. Das Standard-AppKit-App-Menü (Bearbeiten/Fenster/Hilfe,
  Ausblenden/Beenden) blieb englisch, weil die App nur `en` als Bundle-Sprache deklarierte.
  Fix: `Localizable.xcstrings` mit deutscher Lokalisierung + `de` in `knownRegions` → macOS
  rendert die eingebauten Menü-Strings jetzt in der Systemsprache (deutsch auf deutschem
  System, englisch auf englischem). Eigene UI bleibt hart deutsch — echte Volllokalisierung
  (alle App-Strings übersetzbar) wäre ein eigenes Thema.
- ~~**Menü ausdünnen.**~~ *(2026-06-21 erledigt.)* „Dienste"-Untermenü via
  `CommandGroup(replacing: .systemServices) {}` entfernt, totes Standard-Hilfe-Item durch
  eigene „Spitr-Hilfe" ersetzt. Menüleisten-Popover auf Sinnvolles reduziert.

---

## Bekannte Dev-Build-Einschränkungen (kein Bug, kein Fix nötig)

- **Platzhalter-Icon in systemseitigen Anzeigen** (Anmeldeobjekte in den System-
  einstellungen, ggf. Finder/Spotlight). Ursache: veralteter macOS-LaunchServices-Icon-
  Cache beim Lauf aus `DerivedData` mit Personal-Team-Signatur. **Nicht per App-Code
  behebbar** — diese Panels rendern das Icon selbst aus dem registrierten Bundle, es
  gibt keine API zum Überschreiben (anders als das eigene „Über"-Panel, das wir fixen
  konnten). Verschwindet bei der signierten, in `/Applications` installierten Release-App.
  Falls im Dev-Build doch erzwungen werden soll: `sudo`-IconServices-Cache-Reset oder App
  nach `/Applications` kopieren + `lsregister -f`.
