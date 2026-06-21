//
//  DictionaryStore.swift
//  Spitr
//
//  Persistent personal dictionary: user-defined replacement rules applied to a
//  transcript before insertion. Local-only (UserDefaults as JSON). Can be
//  switched off entirely — the feature is opt-out without losing the rules.
//

import Foundation
import Combine

@MainActor
final class DictionaryStore: ObservableObject {

    @Published private(set) var rules: [ReplacementRule] = []

    /// When off, no replacements run. Rules are kept so toggling back is lossless.
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.enabled) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let rules = "dictionary.rules"
        static let enabled = "dictionary.enabled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Default off — Jarek wants to try it before committing to it.
        self.isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? false
        load()
    }

    /// Active rules to apply, or none when disabled.
    var activeRules: [ReplacementRule] { isEnabled ? rules : [] }

    func add() {
        rules.append(ReplacementRule(pattern: "", replacement: ""))
        persist()
    }

    /// Adds (or updates) a populated rule — used by the history correction flow
    /// to turn a fix into a permanent replacement. Matching an existing pattern
    /// (case-insensitively) updates it in place rather than adding a duplicate.
    func add(pattern: String, replacement: String) {
        let p = pattern.trimmingCharacters(in: .whitespaces)
        let r = replacement.trimmingCharacters(in: .whitespaces)
        guard !p.isEmpty else { return }
        if let idx = rules.firstIndex(where: { $0.pattern.caseInsensitiveCompare(p) == .orderedSame }) {
            rules[idx] = ReplacementRule(id: rules[idx].id, pattern: p, replacement: r)
        } else {
            rules.append(ReplacementRule(pattern: p, replacement: r))
        }
        persist()
    }

    func update(_ rule: ReplacementRule) {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[idx] = rule
        persist()
    }

    func delete(_ rule: ReplacementRule) {
        rules.removeAll { $0.id == rule.id }
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: Keys.rules),
              let decoded = try? JSONDecoder().decode([ReplacementRule].self, from: data) else { return }
        rules = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: Keys.rules)
    }
}
