//
//  VoiceCommandEdgeTests.swift
//  SpitrTests
//
//  Edge cases and the documented-but-imperfect behaviours of command matching,
//  so any future change to the matching strategy is a deliberate one.
//

import Testing
import Foundation
@testable import Spitr

@MainActor
struct VoiceCommandEdgeTests {

    private func env() -> (VoiceCommandInterpreter, SettingsStore, HistoryStore, DictionaryStore) {
        let d = makeDefaults()
        return (VoiceCommandInterpreter(),
                SettingsStore(defaults: d),
                HistoryStore(defaults: d),
                DictionaryStore(defaults: d))
    }

    @Test func emptyTranscriptMatchesNothing() {
        let (i, s, h, d) = env()
        #expect(i.match("", settings: s, history: h, dictionary: d) == nil)
    }

    @Test func whitespaceTranscriptMatchesNothing() {
        let (i, s, h, d) = env()
        #expect(i.match("   \n ", settings: s, history: h, dictionary: d) == nil)
    }

    @Test func performingDoesNotTouchUnrelatedState() {
        let (i, s, h, d) = env()
        h.isEnabled = true
        d.isEnabled = true
        s.localeIdentifier = "de-DE"
        i.match("pause", settings: s, history: h, dictionary: d)?.perform()
        // Only isPaused should change.
        #expect(s.isPaused == true)
        #expect(h.isEnabled == true)
        #expect(d.isEnabled == true)
        #expect(s.localeIdentifier == "de-DE")
    }

    // MARK: - Documented limitations (substring + longest-wins)

    @Test func matchingIsSubstringBasedNotWordBased() {
        // KNOWN: phrases are matched as substrings, so a longer word containing a
        // phrase still triggers it. Documented so a future word-boundary change is
        // intentional.
        let (i, s, h, d) = env()
        #expect(i.match("verschnaufpause", settings: s, history: h, dictionary: d)?.id == "pause")
    }

    @Test func withMultipleMatchesTheLongestPhraseWins() {
        // KNOWN: a transcript mentioning two commands resolves to the one whose
        // matched phrase is longest — here "deutsch" (7) beats "weiter" (6).
        let (i, s, h, d) = env()
        let cmd = i.match("weiter auf deutsch", settings: s, history: h, dictionary: d)
        #expect(cmd?.id == "langDE")
    }

    @Test func commandIdsAreUnique() {
        let (i, s, h, d) = env()
        let ids = i.commands(settings: s, history: h, dictionary: d).map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func everyPhraseResolvesToItsOwnCommand() {
        // Each declared phrase, spoken alone, must trigger the command it belongs
        // to — guards against one command's phrase being shadowed by another's.
        let (i, s, h, d) = env()
        for command in i.commands(settings: s, history: h, dictionary: d) {
            for phrase in command.phrases {
                let hit = i.match(phrase, settings: s, history: h, dictionary: d)
                #expect(hit?.id == command.id, "Phrase \"\(phrase)\" resolved to \(hit?.id ?? "nil"), expected \(command.id)")
            }
        }
    }
}
