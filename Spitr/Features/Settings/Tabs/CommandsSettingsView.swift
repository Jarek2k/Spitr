//
//  CommandsSettingsView.swift
//  Spitr
//
//  The "Befehle" tab: a read-only reference of the voice commands available in
//  command mode (hold the hotkey with ⇧).
//

import SwiftUI

struct CommandsSettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var history: HistoryStore
    @ObservedObject var dictionary: DictionaryStore

    private var commands: [VoiceCommand] {
        VoiceCommandInterpreter().commands(settings: settings, history: history, dictionary: dictionary)
    }

    var body: some View {
        Form {
            Section {
                ForEach(commands) { command in
                    LabeledContent(command.title) {
                        Text("»\(command.example)«")
                            .foregroundStyle(.secondary)
                            .font(.body.monospaced())
                    }
                }
            } footer: {
                Text("Halte die Aufnahme-Taste **mit ⇧** und sprich einen Befehl, statt zu diktieren. Der Text wird dann nicht eingefügt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
