//
//  SettingsView.swift
//  Spitr
//
//  Standard macOS settings window (⌘,). Edits the SettingsStore; changes take
//  effect on the next recording without a restart. Split into tabs so the
//  dictation history has room without crowding the preferences.
//

import SwiftUI

/// Shared window metrics so every tab is the same size — otherwise the window
/// height jumps when switching tabs.
private enum SettingsLayout {
    static let width: CGFloat = 460
    static let height: CGFloat = 440
}

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

            CommandsSettingsView(settings: settings, history: history, dictionary: dictionary)
                .tabItem { Label("Befehle", systemImage: "command") }

            HistorySettingsView(history: history)
                .tabItem { Label("Verlauf", systemImage: "clock.arrow.circlepath") }
        }
        .frame(width: SettingsLayout.width, height: SettingsLayout.height)
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
            } footer: {
                Text("Kurzer Ton, sobald das Mikro wirklich aufnimmt — so verlierst du das erste Wort nicht.")
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
                Text("Globaler Kurzbefehl, der das letzte Diktat erneut ins fokussierte Feld einfügt. Mindestens ein ⌘/⌃/⌥ nötig.")
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
        .onAppear {
            inputDevices = AudioDeviceService.inputDevices()
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}

private struct CommandsSettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var history: HistoryStore
    @ObservedObject var dictionary: DictionaryStore

    private var commands: [VoiceCommand] {
        VoiceCommandInterpreter().commands(settings: settings, history: history, dictionary: dictionary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Halte die Aufnahme-Taste **mit ⇧** und sprich einen Befehl, statt zu diktieren. Der Text wird dann nicht eingefügt.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)

            Divider()

            List {
                ForEach(commands) { command in
                    HStack {
                        Text(command.title)
                        Spacer()
                        Text("»\(command.example)«")
                            .foregroundStyle(.secondary)
                            .font(.body.monospaced())
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct VocabularySettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var newTerm = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Eigennamen und Fachbegriffe als **Hinweis** an die Erkennung — tippe einen Begriff und drücke Enter. Hilft oft, aber nicht garantiert. Trifft die Erkennung ein Wort nie, trag es im **Wörterbuch** als feste Ersetzung ein.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Begriff hinzufügen …", text: $newTerm)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addTerm)

            ScrollView {
                if settings.vocabulary.isEmpty {
                    Text("Beispiel: Claude, Xcode, SwiftUI, Parnas")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(settings.vocabulary, id: \.self) { term in
                            VocabularyChip(term: term) { removeTerm(term) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addTerm() {
        let trimmed = newTerm.trimmingCharacters(in: .whitespaces)
        newTerm = ""
        guard !trimmed.isEmpty,
              !settings.vocabulary.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
        else { return }
        settings.vocabularyText = (settings.vocabulary + [trimmed]).joined(separator: "\n")
    }

    private func removeTerm(_ term: String) {
        settings.vocabularyText = settings.vocabulary
            .filter { $0.caseInsensitiveCompare(term) != .orderedSame }
            .joined(separator: "\n")
    }
}

/// A vocabulary term rendered as a removable capsule.
private struct VocabularyChip: View {
    let term: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(term)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Entfernen")
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.secondary.opacity(0.15)))
    }
}

/// Left-to-right wrapping layout for the vocabulary chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        arrange(subviews: subviews, maxWidth: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let positions = arrange(subviews: subviews, maxWidth: bounds.width).positions
        for (index, position) in positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> (positions: [CGPoint], size: CGSize) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

private struct DictionarySettingsView: View {
    @ObservedObject var dictionary: DictionaryStore

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Toggle("Wörterbuch anwenden", isOn: $dictionary.isEnabled)
                    Spacer()
                    Button {
                        dictionary.add()
                    } label: {
                        Label("Regel", systemImage: "plus")
                    }
                }
                Text("Feste Ersetzung **nach** der Erkennung — der harte Weg, wenn ein Wort über das **Vokabular** nicht zuverlässig ankommt. Ganzes Wort, Groß-/Kleinschreibung egal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                HStack {
                    Text("Erkannt").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Ersetzung").frame(maxWidth: .infinity, alignment: .leading)
                    Spacer().frame(width: 24)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                List {
                    ForEach(dictionary.rules) { rule in
                        RuleRow(rule: rule, dictionary: dictionary)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .help("Regel löschen")
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
                        HistoryRow(
                            entry: entry,
                            timestamp: Self.timestamp.string(from: entry.date),
                            onDelete: { history.delete(entry) }
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One dictation entry. Copy/delete are revealed on hover (discoverable without
/// a right-click) and mirrored in a context menu for keyboard/Power users.
private struct HistoryRow: View {
    let entry: HistoryStore.Entry
    let timestamp: String
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var justCopied = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text)
                    .textSelection(.enabled)
                    .lineLimit(4)
                Text(timestamp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            // Always in the layout so the text never reflows on hover — only the
            // visibility toggles. Copy briefly turns into a checkmark (same width).
            HStack(spacing: 2) {
                Button(action: copy) {
                    Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                }
                .help("Kopieren")
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .help("Löschen")
            }
            .buttonStyle(.borderless)
            .imageScale(.medium)
            .opacity(isHovering || justCopied ? 1 : 0)
            .allowsHitTesting(isHovering || justCopied)
            .animation(.easeInOut(duration: 0.12), value: isHovering)
            .animation(.easeInOut(duration: 0.12), value: justCopied)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Kopieren", action: copy)
            Button("Löschen", role: .destructive, action: onDelete)
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
        justCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            justCopied = false
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
            Text(recording ? "Tastenkombination drücken…" : combo.displayString)
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

#Preview {
    SettingsView(settings: SettingsStore(), history: HistoryStore(), dictionary: DictionaryStore())
}
