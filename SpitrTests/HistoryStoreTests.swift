//
//  HistoryStoreTests.swift
//  SpitrTests
//

import Testing
import Foundation
@testable import Spitr

@MainActor
struct HistoryStoreTests {

    @Test func recordsNewestFirst() {
        let h = HistoryStore(defaults: makeDefaults())
        h.record("erste")
        h.record("zweite")
        #expect(h.entries.count == 2)
        #expect(h.entries.first?.text == "zweite")
        #expect(h.entries.last?.text == "erste")
    }

    @Test func ignoresEmptyAndWhitespace() {
        let h = HistoryStore(defaults: makeDefaults())
        h.record("   ")
        h.record("\n\t")
        h.record("")
        #expect(h.entries.isEmpty)
    }

    @Test func trimsStoredText() {
        let h = HistoryStore(defaults: makeDefaults())
        h.record("  hallo welt  ")
        #expect(h.entries.first?.text == "hallo welt")
    }

    @Test func cappedAtHundred() {
        let h = HistoryStore(defaults: makeDefaults())
        for i in 0..<105 { h.record("eintrag \(i)") }
        #expect(h.entries.count == 100)
        // Newest kept, oldest dropped.
        #expect(h.entries.first?.text == "eintrag 104")
        #expect(h.entries.contains { $0.text == "eintrag 0" } == false)
    }

    @Test func disabledDoesNotRecordButKeepsExisting() {
        let h = HistoryStore(defaults: makeDefaults())
        h.record("behalten")
        h.isEnabled = false
        h.record("verworfen")
        #expect(h.entries.count == 1)
        #expect(h.entries.first?.text == "behalten")
    }

    @Test func deleteRemovesOnlyTheEntry() {
        let h = HistoryStore(defaults: makeDefaults())
        h.record("a")
        h.record("b")
        let target = h.entries.first { $0.text == "a" }!
        h.delete(target)
        #expect(h.entries.map(\.text) == ["b"])
    }

    @Test func updateChangesTextKeepingIdentity() {
        let h = HistoryStore(defaults: makeDefaults())
        h.record("Klode")
        let original = h.entries.first!
        h.update(original, newText: "  Claude  ")
        let updated = h.entries.first!
        #expect(updated.text == "Claude")      // trimmed
        #expect(updated.id == original.id)      // same entry
        #expect(updated.date == original.date)
    }

    @Test func updateIgnoresEmptyText() {
        let h = HistoryStore(defaults: makeDefaults())
        h.record("bleibt")
        h.update(h.entries.first!, newText: "   ")
        #expect(h.entries.first?.text == "bleibt")
    }

    @Test func clearEmptiesEverything() {
        let h = HistoryStore(defaults: makeDefaults())
        h.record("a"); h.record("b")
        h.clear()
        #expect(h.entries.isEmpty)
    }

    @Test func entriesAndFlagPersist() {
        let defaults = makeDefaults()
        let first = HistoryStore(defaults: defaults)
        first.record("bleibt")
        first.isEnabled = false

        let second = HistoryStore(defaults: defaults)
        #expect(second.entries.map(\.text) == ["bleibt"])
        #expect(second.isEnabled == false)
    }

    @Test func enabledByDefault() {
        #expect(HistoryStore(defaults: makeDefaults()).isEnabled == true)
    }
}
