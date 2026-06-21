//
//  DictionaryStoreTests.swift
//  SpitrTests
//

import Testing
import Foundation
@testable import Spitr

@MainActor
struct DictionaryStoreTests {

    @Test func disabledByDefault() {
        #expect(DictionaryStore(defaults: makeDefaults()).isEnabled == false)
    }

    @Test func addAppendsEmptyRule() {
        let d = DictionaryStore(defaults: makeDefaults())
        d.add()
        #expect(d.rules.count == 1)
        #expect(d.rules.first?.pattern == "")
        #expect(d.rules.first?.replacement == "")
    }

    @Test func updateChangesRuleById() {
        let d = DictionaryStore(defaults: makeDefaults())
        d.add()
        let id = d.rules[0].id
        d.update(ReplacementRule(id: id, pattern: "klode", replacement: "Claude"))
        #expect(d.rules[0].pattern == "klode")
        #expect(d.rules[0].replacement == "Claude")
        #expect(d.rules[0].id == id)
    }

    @Test func addPopulatedAppendsTrimmedRule() {
        let d = DictionaryStore(defaults: makeDefaults())
        d.add(pattern: "  Klode ", replacement: " Claude ")
        #expect(d.rules.count == 1)
        #expect(d.rules[0].pattern == "Klode")
        #expect(d.rules[0].replacement == "Claude")
    }

    @Test func addPopulatedUpdatesExistingPatternCaseInsensitively() {
        let d = DictionaryStore(defaults: makeDefaults())
        d.add(pattern: "klode", replacement: "Claude")
        d.add(pattern: "KLODE", replacement: "Cloud")
        #expect(d.rules.count == 1)               // upsert, no duplicate
        #expect(d.rules[0].replacement == "Cloud")
    }

    @Test func addPopulatedIgnoresEmptyPattern() {
        let d = DictionaryStore(defaults: makeDefaults())
        d.add(pattern: "   ", replacement: "x")
        #expect(d.rules.isEmpty)
    }

    @Test func deleteRemovesRule() {
        let d = DictionaryStore(defaults: makeDefaults())
        d.add(); d.add()
        d.delete(d.rules[0])
        #expect(d.rules.count == 1)
    }

    @Test func activeRulesRespectEnabledFlag() {
        let d = DictionaryStore(defaults: makeDefaults())
        d.add()
        d.update(ReplacementRule(id: d.rules[0].id, pattern: "a", replacement: "b"))
        #expect(d.activeRules.isEmpty)          // disabled by default
        d.isEnabled = true
        #expect(d.activeRules.count == 1)
    }

    @Test func rulesAndFlagPersist() {
        let defaults = makeDefaults()
        let first = DictionaryStore(defaults: defaults)
        first.add()
        first.update(ReplacementRule(id: first.rules[0].id, pattern: "x", replacement: "y"))
        first.isEnabled = true

        let second = DictionaryStore(defaults: defaults)
        #expect(second.rules.count == 1)
        #expect(second.rules[0].pattern == "x")
        #expect(second.rules[0].replacement == "y")
        #expect(second.isEnabled == true)
    }
}
