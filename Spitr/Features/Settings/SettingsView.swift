//
//  SettingsView.swift
//  Spitr
//
//  Standard macOS settings window (⌘,). Edits the SettingsStore; changes take
//  effect on the next recording without a restart.
//

import SwiftUI

struct SettingsView: View {
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
            } footer: {
                Text("Aufgenommen wird nur, solange du die Taste hältst.")
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
            } footer: {
                Text("Halte diese Taste zum Aufnehmen — eine Modifier-Taste, damit nichts getippt wird.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Beim Anmelden starten", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        LaunchAtLogin.setEnabled(enabled)
                        // Re-read in case the request failed, so the UI never lies.
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            inputDevices = AudioDeviceService.inputDevices()
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}

#Preview {
    SettingsView(settings: SettingsStore())
}
