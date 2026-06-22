//
//  SettingsView.swift
//  Spitr
//
//  Standard macOS settings window (⌘,). Edits the SettingsStore; changes take
//  effect on the next recording without a restart. Each tab lives in its own
//  file under Tabs/ so this stays a thin container.
//

import SwiftUI

/// Shared window metrics so every tab is the same size — otherwise the window
/// height jumps when switching tabs.
enum SettingsLayout {
    static let width: CGFloat = 460
    static let height: CGFloat = 440
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var history: HistoryStore
    @ObservedObject var dictionary: DictionaryStore

    var body: some View {
        TabView(selection: $settings.requestedTab) {
            GeneralSettingsView(settings: settings)
                .tabItem { Label("Allgemein", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            VocabularySettingsView(settings: settings)
                .tabItem { Label("Vokabular", systemImage: "text.word.spacing") }
                .tag(SettingsTab.vocabulary)

            DictionarySettingsView(dictionary: dictionary)
                .tabItem { Label("Wörterbuch", systemImage: "character.book.closed") }
                .tag(SettingsTab.dictionary)

            CommandsSettingsView(settings: settings, history: history, dictionary: dictionary)
                .tabItem { Label("Befehle", systemImage: "command") }
                .tag(SettingsTab.commands)

            HistorySettingsView(history: history, dictionary: dictionary,
                                pendingCorrectionID: $settings.pendingCorrectionID)
                .tabItem { Label("Verlauf", systemImage: "clock.arrow.circlepath") }
                .tag(SettingsTab.history)

            DiagnosticsSettingsView(settings: settings)
                .tabItem { Label("Diagnose", systemImage: "stethoscope") }
                .tag(SettingsTab.diagnostics)
        }
        .frame(width: SettingsLayout.width, height: SettingsLayout.height)
    }
}

#Preview {
    SettingsView(settings: SettingsStore(), history: HistoryStore(), dictionary: DictionaryStore())
}
