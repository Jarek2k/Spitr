//
//  StoreRobustnessTests.swift
//  SpitrTests
//
//  What happens with corrupted or foreign persisted data, unknown identifiers
//  and unknown enum raw values — the stores must degrade gracefully, never crash.
//

import Testing
import Foundation
@testable import Spitr

@MainActor
struct StoreRobustnessTests {

    @Test func historyToleratesCorruptedData() {
        let defaults = makeDefaults()
        defaults.set(Data([0xDE, 0xAD, 0xBE, 0xEF]), forKey: "history.entries")
        let h = HistoryStore(defaults: defaults)
        #expect(h.entries.isEmpty)
        #expect(h.isEnabled == true)
        // Still usable afterwards.
        h.record("ok")
        #expect(h.entries.count == 1)
    }

    @Test func dictionaryToleratesCorruptedData() {
        let defaults = makeDefaults()
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: "dictionary.rules")
        let d = DictionaryStore(defaults: defaults)
        #expect(d.rules.isEmpty)
        d.add()
        #expect(d.rules.count == 1)
    }

    @Test func dictionaryUpdateWithUnknownIdIsNoop() {
        let d = DictionaryStore(defaults: makeDefaults())
        d.add()
        let before = d.rules
        d.update(ReplacementRule(pattern: "x", replacement: "y"))   // random id
        #expect(d.rules == before)
    }

    @Test func dictionaryDeleteWithUnknownIdIsNoop() {
        let d = DictionaryStore(defaults: makeDefaults())
        d.add()
        d.delete(ReplacementRule(pattern: "x", replacement: "y"))   // random id
        #expect(d.rules.count == 1)
    }

    @Test func settingsFallBackOnUnknownEngineRawValue() {
        let defaults = makeDefaults()
        defaults.set("definitely-not-an-engine", forKey: "engineKind")
        #expect(SettingsStore(defaults: defaults).engineKind == .apple)
    }

    @Test func settingsFallBackOnUnknownWaveformRawValue() {
        let defaults = makeDefaults()
        defaults.set("squiggles", forKey: "waveformStyle")
        #expect(SettingsStore(defaults: defaults).waveformStyle == .bars)
    }
}
