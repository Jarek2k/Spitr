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
            } footer: {
                if settings.engineKind == .whisperKit {
                    Text("WhisperKit folgt — bis dahin wird Apple Speech verwendet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("Sprache", selection: $settings.localeIdentifier) {
                    ForEach(Self.languages, id: \.id) { lang in
                        Text(lang.name).tag(lang.id)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    SettingsView(settings: SettingsStore())
}
