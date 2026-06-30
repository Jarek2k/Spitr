//
//  DictionarySettingsView.swift
//  Spitr
//
//  The "Wörterbuch" tab: fixed post-recognition replacements (whole word,
//  case-insensitive) for words the engine reliably mishears.
//

import SwiftUI

struct DictionarySettingsView: View {
    @ObservedObject var dictionary: DictionaryStore

    var body: some View {
        Form {
            Section {
                Toggle("Wörterbuch anwenden", isOn: $dictionary.isEnabled)
            } footer: {
                Text("Feste Ersetzung **nach** der Erkennung — der harte Weg, wenn ein Wort über das **Vokabular** nicht zuverlässig ankommt. Ganzes Wort, Groß-/Kleinschreibung egal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                if dictionary.rules.isEmpty {
                    Text("Noch keine Regeln. „Erkannt“ wird durch „Ersetzung“ getauscht.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(dictionary.rules) { rule in
                        RuleRow(rule: rule, dictionary: dictionary)
                    }
                }

                Button {
                    dictionary.add()
                } label: {
                    Label("Regel hinzufügen", systemImage: "plus")
                }
            } header: {
                HStack {
                    Text("Erkannt").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Ersetzung").frame(maxWidth: .infinity, alignment: .leading)
                    Spacer().frame(width: 20)
                }
            }
            .opacity(dictionary.isEnabled ? 1 : 0.55)
        }
        .formStyle(.grouped)
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
            // labelsHidden(): inside a Form, SwiftUI would otherwise promote the
            // placeholder to a persistent leading label, repeating "Klode"/"Claude"
            // on every row. Hidden, the strings stay as ghost hints in empty fields
            // only — the column headers above carry the meaning.
            TextField("Klode", text: $pattern)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .onChange(of: pattern) { _, _ in commit() }
            TextField("Claude", text: $replacement)
                .labelsHidden()
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
