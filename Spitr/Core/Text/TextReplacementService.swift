//
//  TextReplacementService.swift
//  Spitr
//
//  Post-processing step: applies the personal dictionary to a finished
//  transcript before insertion. Pure String → String so it stays testable and
//  free of side effects — the decision "how do we match" lives here behind the
//  protocol, the rules themselves live in DictionaryStore.
//

import Foundation

/// A single replacement rule: every whole-word, case-insensitive occurrence of
/// `pattern` becomes `replacement`.
struct ReplacementRule: Identifiable, Codable, Equatable {
    let id: UUID
    var pattern: String
    var replacement: String

    init(id: UUID = UUID(), pattern: String, replacement: String) {
        self.id = id
        self.pattern = pattern
        self.replacement = replacement
    }
}

protocol TextReplacing {
    /// Applies `rules` to `text` in order, returning the rewritten string.
    func apply(_ rules: [ReplacementRule], to text: String) -> String
}

/// Whole-word (\b…\b), case-insensitive matching. The replacement is inserted
/// literally — regex metacharacters in the substitution are not interpreted.
struct TextReplacementService: TextReplacing {

    func apply(_ rules: [ReplacementRule], to text: String) -> String {
        rules.reduce(text) { partial, rule in
            let pattern = rule.pattern.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pattern.isEmpty else { return partial }

            // Only anchor with a word boundary on a side that ends in a word
            // character. Otherwise terms like "c++" or ".net" — where the edge is
            // punctuation — would never match (\b sits between two non-word chars).
            let core = NSRegularExpression.escapedPattern(for: pattern)
            let lead = pattern.first.map(Self.isWordCharacter) ?? false
            let trail = pattern.last.map(Self.isWordCharacter) ?? false
            let anchored = (lead ? "\\b" : "") + core + (trail ? "\\b" : "")

            guard let regex = try? NSRegularExpression(
                pattern: anchored,
                options: [.caseInsensitive]
            ) else { return partial }

            let range = NSRange(partial.startIndex..., in: partial)
            let template = NSRegularExpression.escapedTemplate(for: rule.replacement)
            return regex.stringByReplacingMatches(
                in: partial, range: range, withTemplate: template
            )
        }
    }

    private static func isWordCharacter(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || c == "_"
    }
}
