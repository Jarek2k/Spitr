//
//  GeneralSettingsView.swift
//  Spitr
//
//  The "Allgemein" tab: engine/model, microphone, recognition language, hotkey,
//  chimes, smart spacing, the re-insert shortcut and launch-at-login.
//

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: SettingsStore

    /// Connected input devices, refreshed when the window appears.
    @State private var inputDevices: [AudioInputDevice] = []

    /// Mirrors the live SMAppService login-item status; the service is the
    /// source of truth, this just drives the Toggle.
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    /// Curated set of recognition languages. Kept short on purpose — the full
    /// system list is overwhelming and most are irrelevant for this app.
    private static let languages: [(id: String, name: String)] = [
        ("de-DE", "Deutsch"),
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("fr-FR", "Français"),
        ("es-ES", "Español"),
        ("it-IT", "Italiano"),
        ("nl-NL", "Nederlands"),
    ]

    var body: some View {
        Form {
            Section {
                Picker("Engine", selection: $settings.engineKind) {
                    ForEach(EngineKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }

                if settings.engineKind == .whisperKit {
                    Picker("Modell", selection: $settings.whisperModel) {
                        ForEach(WhisperKitEngine.selectableModels, id: \.id) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                }
            } footer: {
                if settings.engineKind == .whisperKit {
                    Text("WhisperKit lädt das Modell beim ersten Mal einmalig herunter; danach läuft alles offline.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("Mikrofon", selection: $settings.inputDeviceUID) {
                    Text("Systemstandard").tag("")
                    ForEach(inputDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                    // Keep a vanished but still-selected device visible.
                    if !settings.inputDeviceUID.isEmpty,
                       !inputDevices.contains(where: { $0.uid == settings.inputDeviceUID }) {
                        Text("Nicht verfügbar").tag(settings.inputDeviceUID)
                    }
                }

                Toggle("Sprachisolierung", isOn: $settings.voiceIsolation)
            } footer: {
                Text("Aufgenommen wird nur, solange du die Taste hältst. Sprachisolierung filtert Hintergrundgeräusche (z. B. Fernseher) und gleicht die Lautstärke an — bei sehr ruhiger Umgebung kannst du sie ausschalten.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Sprache", selection: $settings.localeIdentifier) {
                    ForEach(Self.languages, id: \.id) { lang in
                        Text(lang.name).tag(lang.id)
                    }
                }

                Picker("Aufnahme-Taste", selection: $settings.hotkeyKeyCode) {
                    ForEach(HotkeyConfig.selectable, id: \.keyCode) { config in
                        Text(config.displayName).tag(config.keyCode)
                    }
                }

                if settings.hotkeyKeyCode == HotkeyConfig.function.keyCode {
                    Text("Die fn-Taste wird nur von der MacBook-Tastatur erkannt, nicht von externen Tastaturen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("Wellenform", selection: $settings.waveformStyle) {
                    ForEach(WaveformStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
            } footer: {
                Text("Halte diese Taste zum Aufnehmen — eine Modifier-Taste, damit nichts getippt wird.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Ton bei Aufnahmebereitschaft", isOn: $settings.playReadyChime)
                Toggle("Ton bei Aufnahme-Ende", isOn: $settings.playDoneChime)
            } footer: {
                Text("Kurze Töne, wenn das Mikro wirklich aufnimmt (Beginn) und wenn der Text eingefügt wurde (Ende) — so verlierst du das erste Wort nicht und weißt, wann die Umwandlung fertig ist.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Intelligente Leerzeichen", isOn: $settings.smartSpacing)
            } footer: {
                Text("Fasst doppelte Leerzeichen zusammen und setzt automatisch ein Leerzeichen vor den Text, wenn er sonst am vorigen Wort klebt. Das Leerzeichen davor klappt nur in Apps, die ihren Textkontext freigeben (native Apps; in Electron wie VS Code/Browser entfällt es).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Erneut einfügen") {
                    ShortcutRecorderField(combo: $settings.reinsertShortcut)
                }
            } footer: {
                Text("Globaler Kurzbefehl, der die letzte Spracheingabe erneut ins fokussierte Feld einfügt. Mindestens ein ⌘/⌃/⌥ nötig.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Beim Anmelden öffnen", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        LaunchAtLogin.setEnabled(enabled)
                        // Re-read in case the request failed, so the UI never lies.
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            inputDevices = AudioDeviceService.inputDevices()
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}

/// A click-to-record shortcut field: tap to arm, then press a chord. Captures
/// the next key-down (with modifiers) via a local event monitor and stores it as
/// a KeyCombo. Escape cancels; invalid chords (no ⌘/⌃/⌥) are ignored so it keeps
/// waiting. The monitor consumes the event so it doesn't leak into the form.
private struct ShortcutRecorderField: View {
    @Binding var combo: KeyCombo
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Group {
                if recording {
                    Text("Tastenkombination drücken…")
                } else {
                    Text(verbatim: combo.displayString)
                }
            }
            .monospaced()
            .frame(minWidth: 130)
        }
        .buttonStyle(.bordered)
        .help(recording ? "Drücke die gewünschte Kombination, Esc bricht ab." : "Klicken, dann Kombination drücken.")
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stop(); return nil }   // Escape cancels
            guard let chars = event.charactersIgnoringModifiers,
                  let scalar = chars.unicodeScalars.first, scalar.value >= 0x20 else { return nil }
            let candidate = KeyCombo(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags.intersection(KeyCombo.relevantMask),
                label: chars
            )
            guard candidate.isValid else { return nil }       // keep waiting
            combo = candidate
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
    }
}
