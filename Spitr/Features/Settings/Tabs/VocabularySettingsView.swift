//
//  VocabularySettingsView.swift
//  Spitr
//
//  The "Vokabular" tab: custom terms fed to the engine as a recognition hint,
//  shown as removable chips.
//

import SwiftUI

struct VocabularySettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var newTerm = ""

    var body: some View {
        Form {
            Section {
                TextField("Begriff hinzufügen", text: $newTerm)
                    .onSubmit(addTerm)
            } footer: {
                Text("Eigennamen und Fachbegriffe als **Hinweis** an die Erkennung — tippe einen Begriff und drücke Enter. Hilft oft, aber nicht garantiert. Trifft die Erkennung ein Wort nie, trag es im **Wörterbuch** als feste Ersetzung ein.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Begriffe") {
                if settings.vocabulary.isEmpty {
                    Text("Beispiel: Claude, Xcode, SwiftUI, Parnas")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(settings.vocabulary, id: \.self) { term in
                            VocabularyChip(term: term) { removeTerm(term) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .formStyle(.grouped)
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
