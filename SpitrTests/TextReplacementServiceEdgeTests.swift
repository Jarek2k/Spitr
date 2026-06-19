//
//  TextReplacementServiceEdgeTests.swift
//  SpitrTests
//
//  Edge cases for the dictionary replacement: punctuation-bounded terms, regex
//  metacharacters, Unicode word boundaries, string edges and multiline text.
//

import Testing
@testable import Spitr

struct TextReplacementServiceEdgeTests {

    let service = TextReplacementService()

    @Test func matchesTermEndingInPunctuation() {
        // Regression: "\b…\b" used to make this impossible.
        let rules = [ReplacementRule(pattern: "c++", replacement: "cpp")]
        #expect(service.apply(rules, to: "ich nutze c++ gern") == "ich nutze cpp gern")
    }

    @Test func matchesTermStartingWithPunctuation() {
        let rules = [ReplacementRule(pattern: ".net", replacement: "dotnet")]
        #expect(service.apply(rules, to: "läuft auf .net hier") == "läuft auf dotnet hier")
    }

    @Test func regexMetacharactersAreLiteral() {
        // "a.b" must not match "aXb".
        let rules = [ReplacementRule(pattern: "a.b", replacement: "DOT")]
        #expect(service.apply(rules, to: "aXb und a.b") == "aXb und DOT")
    }

    @Test func unicodeWordBoundaries() {
        let rules = [ReplacementRule(pattern: "müller", replacement: "Müller")]
        #expect(service.apply(rules, to: "Herr müller kommt") == "Herr Müller kommt")
        // …but not inside another word.
        #expect(service.apply(rules, to: "müllerstraße") == "müllerstraße")
    }

    @Test func matchesAtStringStartAndEnd() {
        let rules = [ReplacementRule(pattern: "klode", replacement: "Claude")]
        #expect(service.apply(rules, to: "Klode") == "Claude")
        #expect(service.apply(rules, to: "Klode hilft") == "Claude hilft")
        #expect(service.apply(rules, to: "frag Klode") == "frag Claude")
    }

    @Test func replacementWithBackslashStaysLiteral() {
        let rules = [ReplacementRule(pattern: "pfad", replacement: #"C:\temp"#)]
        #expect(service.apply(rules, to: "der pfad") == #"der C:\temp"#)
    }

    @Test func preservesNewlines() {
        let rules = [ReplacementRule(pattern: "klode", replacement: "Claude")]
        #expect(service.apply(rules, to: "Klode\nzweite Zeile") == "Claude\nzweite Zeile")
    }

    @Test func replacesEveryOccurrence() {
        let rules = [ReplacementRule(pattern: "klode", replacement: "Claude")]
        #expect(service.apply(rules, to: "Klode und Klode") == "Claude und Claude")
    }

    @Test func emptyRulesLeaveTextUntouched() {
        #expect(service.apply([], to: "unverändert") == "unverändert")
    }

    @Test func ruleWhosePatternIsOnlyPunctuationStillWorks() {
        // No word edges at all → no boundaries; must not crash and should match.
        let rules = [ReplacementRule(pattern: "->", replacement: "→")]
        #expect(service.apply(rules, to: "a -> b") == "a → b")
    }
}
