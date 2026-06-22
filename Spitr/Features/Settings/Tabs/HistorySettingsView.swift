//
//  HistorySettingsView.swift
//  Spitr
//
//  The "Verlauf" tab: recent dictations with copy/correct/delete, plus the
//  correction sheet that turns a misrecognized word into a permanent rule.
//

import SwiftUI

struct HistorySettingsView: View {
    @ObservedObject var history: HistoryStore
    @ObservedObject var dictionary: DictionaryStore
    /// Set from outside (menu → "correct last dictation") to auto-open the sheet.
    @Binding var pendingCorrectionID: UUID?

    @State private var correctingEntry: HistoryStore.Entry?

    private static let timestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Form {
            Section {
                Toggle("Verlauf aufzeichnen", isOn: $history.isEnabled)
            }

            Section {
                if history.entries.isEmpty {
                    Text("Noch keine Spracheingaben.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(history.entries) { entry in
                        HistoryRow(
                            entry: entry,
                            timestamp: Self.timestamp.string(from: entry.date),
                            onCorrect: { correctingEntry = entry },
                            onDelete: { history.delete(entry) }
                        )
                    }
                }
            } header: {
                HStack {
                    Text("Letzte Spracheingaben")
                    Spacer()
                    Button("Verlauf löschen", role: .destructive) { history.clear() }
                        .buttonStyle(.borderless)
                        .disabled(history.entries.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $correctingEntry) { entry in
            CorrectionSheet(entry: entry, history: history, dictionary: dictionary)
        }
        .onAppear(perform: consumePending)
        .onChange(of: pendingCorrectionID) { _, _ in consumePending() }
    }

    /// Opens the correction sheet for an externally requested entry, then clears
    /// the request so it fires only once.
    private func consumePending() {
        guard let id = pendingCorrectionID,
              let entry = history.entries.first(where: { $0.id == id }) else { return }
        correctingEntry = entry
        pendingCorrectionID = nil
    }
}

/// Turn a misrecognized word into a permanent dictionary rule — the
/// app-independent fix (works regardless of the target app, unlike a Services
/// menu). Tap the wrong word, type the replacement, save: the rule then applies
/// to all future voice input, and this entry is corrected too.
private struct CorrectionSheet: View {
    let entry: HistoryStore.Entry
    @ObservedObject var history: HistoryStore
    @ObservedObject var dictionary: DictionaryStore
    @Environment(\.dismiss) private var dismiss

    @State private var wrongWord = ""
    @State private var replacement = ""
    @FocusState private var replacementFocused: Bool

    /// Distinct recognized words (punctuation trimmed), in order — the tap targets
    /// that fill the "wrong word" field without retyping.
    private var words: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for token in entry.text.split(whereSeparator: \.isWhitespace) {
            let word = Self.trimPunctuation(String(token))
            guard !word.isEmpty, seen.insert(word.lowercased()).inserted else { continue }
            result.append(word)
        }
        return result
    }

    private var canSave: Bool {
        !wrongWord.trimmingCharacters(in: .whitespaces).isEmpty &&
        !replacement.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Spracheingabe korrigieren")
                .font(.headline)
            Text("Tippe das falsch erkannte Wort an und gib ein, wodurch es ersetzt werden soll. Die Regel gilt dann automatisch für alle künftigen Spracheingaben.")
                .font(.caption)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 6) {
                ForEach(words, id: \.self) { word in
                    let selected = word.caseInsensitiveCompare(wrongWord) == .orderedSame
                    Button {
                        wrongWord = word
                        replacementFocused = true
                    } label: {
                        Text(word)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(selected ? Color.accentColor : Color.secondary.opacity(0.15)))
                            .foregroundStyle(selected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Falsch erkannt")
                        .gridColumnAlignment(.trailing)
                        .foregroundStyle(.secondary)
                    TextField("Wort", text: $wrongWord)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Ersetzen durch")
                        .gridColumnAlignment(.trailing)
                        .foregroundStyle(.secondary)
                    TextField("richtiges Wort", text: $replacement)
                        .textFieldStyle(.roundedBorder)
                        .focused($replacementFocused)
                }
            }

            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Regel sichern", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func save() {
        let from = wrongWord.trimmingCharacters(in: .whitespaces)
        let to = replacement.trimmingCharacters(in: .whitespaces)
        guard !from.isEmpty, !to.isEmpty else { return }
        dictionary.add(pattern: from, replacement: to)
        // A rule only takes effect while the dictionary is applied; the user just
        // asked for one, so make sure it's on.
        if !dictionary.isEnabled { dictionary.isEnabled = true }
        // Fix this entry too, so the history reflects the correction.
        let corrected = TextReplacementService()
            .apply([ReplacementRule(pattern: from, replacement: to)], to: entry.text)
        history.update(entry, newText: corrected)
        dismiss()
    }

    private static func trimPunctuation(_ word: String) -> String {
        word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }
}

/// One dictation entry. Copy/delete are revealed on hover (discoverable without
/// a right-click) and mirrored in a context menu for keyboard/Power users.
private struct HistoryRow: View {
    let entry: HistoryStore.Entry
    let timestamp: String
    let onCorrect: () -> Void
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
                Button(action: onCorrect) {
                    Image(systemName: "pencil")
                }
                .help("Korrigieren")
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
            Button("Korrigieren", action: onCorrect)
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
