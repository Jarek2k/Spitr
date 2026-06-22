//
//  DiagnosticsSettingsView.swift
//  Spitr
//
//  The "Diagnose" tab: verbose-logging toggle and a reveal for the on-device
//  log folder. The log never contains dictated text.
//

import SwiftUI

struct DiagnosticsSettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Ausführliches Protokoll", isOn: $settings.verboseLogging)
                    .onChange(of: settings.verboseLogging) { _, on in
                        LogStore.shared.setVerbose(on)
                    }
            } footer: {
                Text("Schreibt zusätzlich regelmäßig Speicher- und Thread-Werte ins Protokoll — nützlich, um über mehrere Tage Lecks aufzuspüren. Aus reicht das normale Protokoll mit Fehlern und Zeiten.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    LogStore.shared.flush()
                    NSWorkspace.shared.open(LogStore.shared.folder)
                } label: {
                    Label("Protokoll-Ordner öffnen", systemImage: "folder")
                }
            } footer: {
                Text("Das Protokoll liegt unter ~/Library/Logs/Spitr und enthält nie deinen diktierten Text — nur Ereignisse, Zeiten und Fehler. Es bleibt komplett auf deinem Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
