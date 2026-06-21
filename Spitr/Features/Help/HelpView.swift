//
//  HelpView.swift
//  Spitr
//
//  In-app usage guide shown from Help ▸ Spitr-Hilfe. Kept fully on-device (no
//  help book server, no web links) so it works offline like the rest of the app.
//

import SwiftUI

struct HelpView: View {
    private struct Topic: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
    }

    private let topics: [Topic] = [
        Topic(symbol: "mic.fill",
              title: "Diktieren",
              detail: "Halte die Aufnahme-Taste, sprich, lass los — der erkannte Text landet im gerade fokussierten Feld. Aufgenommen wird nur, solange du die Taste hältst."),
        Topic(symbol: "command.circle.fill",
              title: "Befehlsmodus",
              detail: "Halte die Aufnahme-Taste zusätzlich mit ⇧ und sprich einen Befehl (z. B. »pause«, »weiter«, »WhisperKit«). Der Text wird dann ausgeführt statt eingefügt. Alle Befehle stehen in den Einstellungen unter „Befehle“."),
        Topic(symbol: "escape",
              title: "Aufnahme abbrechen",
              detail: "Drücke Esc, während du die Aufnahme-Taste hältst. Nichts wird transkribiert oder eingefügt — praktisch bei einem Versprecher."),
        Topic(symbol: "arrow.uturn.left.circle",
              title: "Letztes Diktat erneut einfügen",
              detail: "War der Fokus beim Loslassen falsch, fügt der globale Kurzbefehl (Standard ⌃⌥⌘V, frei belegbar) das letzte Diktat erneut ins aktive Feld ein."),
        Topic(symbol: "text.word.spacing",
              title: "Vokabular & Wörterbuch",
              detail: "„Vokabular“ gibt der Erkennung Eigennamen/Fachbegriffe als Hinweis mit (hilft oft, nicht garantiert). „Wörterbuch“ ersetzt ein Wort fest nach der Erkennung — der harte Weg, wenn ein Begriff nie korrekt ankommt."),
        Topic(symbol: "cpu",
              title: "Engines",
              detail: "Apple Speech ist der schnelle Standard ohne Download. WhisperKit ist die Qualitätsoption; das Modell wird beim ersten Aktivieren einmalig geladen, danach läuft alles offline."),
        Topic(symbol: "lock.fill",
              title: "Privatsphäre",
              detail: "Alles läuft on-device. Keine Cloud, keine Telemetrie. Einzige Ausnahme: der einmalige WhisperKit-Modell-Download."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                if let icon = AppDelegate.bundleIcon() {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 48, height: 48)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spitr-Hilfe")
                        .font(.title2.bold())
                    Text("Taste halten, sprechen, loslassen — der Text landet im aktiven Fenster.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(topics) { topic in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: topic.symbol)
                                .font(.title3)
                                .foregroundStyle(.tint)
                                .frame(width: 26, alignment: .center)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(topic.title)
                                    .font(.headline)
                                Text(topic.detail)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 460, height: 540)
    }
}

#Preview {
    HelpView()
}
