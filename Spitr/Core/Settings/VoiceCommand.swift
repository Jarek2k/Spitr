//
//  VoiceCommand.swift
//  Spitr
//
//  Voice command mode: when recording is triggered with the command modifier
//  (Shift) held, the spoken words aren't inserted as text but matched against
//  these commands to flip Spitr's own settings hands-free.
//
//  One source of truth: the interpreter builds the command list from the
//  stores, and both the matcher and the Settings list read it — so the list
//  shown to the user can never drift from what actually runs. Adding a command
//  is one entry in `commands(...)`.
//

import Foundation

@MainActor
struct VoiceCommand: Identifiable {
    let id: String
    /// Human-readable name for the command list.
    let title: String
    /// Spoken phrases that trigger it (lowercased, matched as substrings).
    let phrases: [String]
    /// Applies the command.
    let perform: () -> Void

    /// The phrase shown as an example in the UI.
    var example: String { phrases.first ?? "" }
}

@MainActor
struct VoiceCommandInterpreter {

    /// All commands, built against the live stores.
    func commands(settings: SettingsStore,
                  history: HistoryStore,
                  dictionary: DictionaryStore) -> [VoiceCommand] {
        [
            VoiceCommand(id: "pause", title: String(localized: "Pausieren"),
                         phrases: ["pause", "pausier", "anhalten", "stopp"]) {
                settings.isPaused = true
            },
            VoiceCommand(id: "resume", title: String(localized: "Fortsetzen"),
                         phrases: ["weiter", "fortsetzen", "aktivier", "los gehts", "los geht's"]) {
                settings.isPaused = false
            },
            VoiceCommand(id: "offline", title: String(localized: "Offline-Modus (Apple Speech)"),
                         phrases: ["offline"]) {
                settings.engineKind = .apple
            },
            VoiceCommand(id: "engineApple", title: String(localized: "Engine: Apple Speech"),
                         phrases: ["apple speech", "apple"]) {
                settings.engineKind = .apple
            },
            VoiceCommand(id: "engineWhisper", title: String(localized: "Engine: WhisperKit"),
                         phrases: ["whisperkit", "whisper kit", "whisper"]) {
                settings.engineKind = .whisperKit
            },
            VoiceCommand(id: "langDE", title: String(localized: "Sprache: Deutsch"),
                         phrases: ["deutsch", "german"]) {
                settings.localeIdentifier = "de-DE"
            },
            VoiceCommand(id: "langEN", title: String(localized: "Sprache: Englisch"),
                         phrases: ["englisch", "english"]) {
                settings.localeIdentifier = "en-US"
            },
            VoiceCommand(id: "dictOn", title: String(localized: "Wörterbuch an"),
                         phrases: ["wörterbuch an", "wörterbuch ein", "dictionary on"]) {
                dictionary.isEnabled = true
            },
            VoiceCommand(id: "dictOff", title: String(localized: "Wörterbuch aus"),
                         phrases: ["wörterbuch aus", "dictionary off"]) {
                dictionary.isEnabled = false
            },
            VoiceCommand(id: "histOn", title: String(localized: "Verlauf an"),
                         phrases: ["verlauf an", "verlauf ein", "history on"]) {
                history.isEnabled = true
            },
            VoiceCommand(id: "histOff", title: String(localized: "Verlauf aus"),
                         phrases: ["verlauf aus", "history off"]) {
                history.isEnabled = false
            },
        ]
    }

    /// Returns the first matching command for a spoken transcript, or nil.
    /// Phrases are checked longest-first so "wörterbuch aus" wins over "aus".
    func match(_ transcript: String,
               settings: SettingsStore,
               history: HistoryStore,
               dictionary: DictionaryStore) -> VoiceCommand? {
        let needle = transcript.lowercased()
        let all = commands(settings: settings, history: history, dictionary: dictionary)
        return all
            .filter { cmd in cmd.phrases.contains { needle.contains($0) } }
            .max { lhs, rhs in lhs.longestMatch(in: needle) < rhs.longestMatch(in: needle) }
    }
}

private extension VoiceCommand {
    /// Length of the longest of this command's phrases found in `needle`.
    func longestMatch(in needle: String) -> Int {
        phrases.filter { needle.contains($0) }.map(\.count).max() ?? 0
    }
}
