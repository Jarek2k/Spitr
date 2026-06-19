//
//  SettingsView.swift
//  Spitr
//
//  Standard macOS settings window (⌘,). Edits the SettingsStore; changes take
//  effect on the next recording without a restart. Split into tabs so the
//  dictation history has room without crowding the preferences.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var history: HistoryStore
    @ObservedObject var dictionary: DictionaryStore

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem { Label("Allgemein", systemImage: "gearshape") }

            VocabularySettingsView(settings: settings)
                .tabItem { Label("Vokabular", systemImage: "text.word.spacing") }

            DictionarySettingsView(dictionary: dictionary)
                .tabItem { Label("Wörterbuch", systemImage: "character.book.closed") }

            HistorySettingsView(history: history)
                .tabItem { Label("Verlauf", systemImage: "clock.arrow.circlepath") }
        }
        .frame(width: 460)
    }
}

private struct GeneralSettingsView: View {
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
                Toggle("Beim Anmelden starten", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        LaunchAtLogin.setEnabled(enabled)
                        // Re-read in case the request failed, so the UI never lies.
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            inputDevices = AudioDeviceService.inputDevices()
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}

private struct VocabularySettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Eigennamen und Fachbegriffe — ein Begriff pro Zeile. Die Erkennung wird darauf vorbereitet, damit sie nicht verhört werden.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $settings.vocabularyText)
                .font(.body.monospaced())
                .frame(minHeight: 240)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.quaternary)
                )

            Text("Beispiel: Claude, Xcode, SwiftUI, Parnas")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(height: 360)
    }
}

private struct DictionarySettingsView: View {
    @ObservedObject var dictionary: DictionaryStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle("Wörterbuch anwenden", isOn: $dictionary.isEnabled)
                Spacer()
                Button {
                    dictionary.add()
                } label: {
                    Label("Regel", systemImage: "plus")
                }
            }
            .padding(12)

            Divider()

            if dictionary.rules.isEmpty {
                Spacer()
                Text("Noch keine Regeln. „Erkannt“ wird durch „Ersetzung“ getauscht.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                List {
                    HStack {
                        Text("Erkannt").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Ersetzung").frame(maxWidth: .infinity, alignment: .leading)
                        Spacer().frame(width: 24)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    ForEach(dictionary.rules) { rule in
                        RuleRow(rule: rule, dictionary: dictionary)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(height: 360)
        .opacity(dictionary.isEnabled ? 1 : 0.55)
    }
}

/// One editable replacement rule. Edits are committed back to the store on change.
private struct RuleRow: View {
    let rule: ReplacementRule
    @ObservedObject var dictionary: DictionaryStore

    @State private var pattern: String
    @State private var replacement: String

    init(rule: ReplacementRule, dictionary: DictionaryStore) {
        self.rule = rule
        self.dictionary = dictionary
        _pattern = State(initialValue: rule.pattern)
        _replacement = State(initialValue: rule.replacement)
    }

    var body: some View {
        HStack {
            TextField("Klode", text: $pattern)
                .textFieldStyle(.roundedBorder)
                .onChange(of: pattern) { _, _ in commit() }
            TextField("Claude", text: $replacement)
                .textFieldStyle(.roundedBorder)
                .onChange(of: replacement) { _, _ in commit() }
            Button {
                dictionary.delete(rule)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    private func commit() {
        dictionary.update(ReplacementRule(id: rule.id, pattern: pattern, replacement: replacement))
    }
}

private struct HistorySettingsView: View {
    @ObservedObject var history: HistoryStore

    private static let timestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle("Verlauf aufzeichnen", isOn: $history.isEnabled)
                Spacer()
                Button("Verlauf löschen", role: .destructive) { history.clear() }
                    .disabled(history.entries.isEmpty)
            }
            .padding(12)

            Divider()

            if history.entries.isEmpty {
                Spacer()
                Text("Noch keine Diktate.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(history.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.text)
                                .textSelection(.enabled)
                                .lineLimit(4)
                            Text(Self.timestamp.string(from: entry.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .contextMenu {
                            Button("Kopieren") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(entry.text, forType: .string)
                            }
                            Button("Löschen", role: .destructive) { history.delete(entry) }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(height: 360)
    }
}

#Preview {
    SettingsView(settings: SettingsStore(), history: HistoryStore(), dictionary: DictionaryStore())
}
