//
//  TextReplacementServiceTests.swift
//  SpitrTests
//

import Testing
@testable import Spitr

struct TextReplacementServiceTests {

    let service = TextReplacementService()

    @Test func replacesWholeWordCaseInsensitively() {
        let rules = [ReplacementRule(pattern: "klode", replacement: "Claude")]
        #expect(service.apply(rules, to: "Frag mal Klode.") == "Frag mal Claude.")
    }

    @Test func doesNotReplaceInsideOtherWords() {
        let rules = [ReplacementRule(pattern: "git", replacement: "GitHub")]
        #expect(service.apply(rules, to: "digital") == "digital")
    }

    @Test func appliesRulesInOrder() {
        let rules = [
            ReplacementRule(pattern: "a", replacement: "b"),
            ReplacementRule(pattern: "b", replacement: "c"),
        ]
        #expect(service.apply(rules, to: "a") == "c")
    }

    @Test func ignoresEmptyPattern() {
        let rules = [ReplacementRule(pattern: "   ", replacement: "x")]
        #expect(service.apply(rules, to: "hallo") == "hallo")
    }

    @Test func treatsReplacementLiterally() {
        let rules = [ReplacementRule(pattern: "preis", replacement: "$5")]
        #expect(service.apply(rules, to: "der Preis") == "der $5")
    }

    @Test func handlesMultiWordPattern() {
        let rules = [ReplacementRule(pattern: "swift ui", replacement: "SwiftUI")]
        #expect(service.apply(rules, to: "ich mag Swift UI sehr") == "ich mag SwiftUI sehr")
    }
}
