//
//  HistoryStore.swift
//  Spitr
//
//  Local, deletable dictation history. Stays on-device (UserDefaults as JSON),
//  capped to the most recent entries. Recording can be switched off entirely —
//  privacy by design, so the user stays in control of what is kept.
//

import Foundation
import Combine

@MainActor
final class HistoryStore: ObservableObject {

    struct Entry: Identifiable, Codable, Equatable {
        let id: UUID
        let text: String
        let date: Date

        init(text: String, date: Date = .now) {
            self.id = UUID()
            self.text = text
            self.date = date
        }

        /// Preserves an existing id/date — used when correcting an entry in place.
        init(id: UUID, text: String, date: Date) {
            self.id = id
            self.text = text
            self.date = date
        }
    }

    /// Most recent first.
    @Published private(set) var entries: [Entry] = []

    /// When off, transcripts are not recorded. Existing entries are kept until
    /// the user clears them explicitly.
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.enabled) }
    }

    /// Keep the list bounded so UserDefaults stays small. Sized to hold a
    /// multi-day dictation session for later quality review.
    private let limit = 1000

    private let defaults: UserDefaults

    private enum Keys {
        static let entries = "history.entries"
        static let enabled = "history.enabled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Default on; it's a convenience feature and stays fully local.
        self.isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        load()
    }

    /// Records a transcript. No-op when disabled or empty.
    func record(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnabled, !trimmed.isEmpty else { return }
        entries.insert(Entry(text: trimmed), at: 0)
        if entries.count > limit { entries.removeLast(entries.count - limit) }
        persist()
    }

    /// Replaces an entry's text in place (keeps id and date). No-op when the new
    /// text is empty or the entry is gone.
    func update(_ entry: Entry, newText: String) {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx] = Entry(id: entry.id, text: trimmed, date: entry.date)
        persist()
    }

    func delete(_ entry: Entry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func clear() {
        entries.removeAll()
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: Keys.entries),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        entries = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Keys.entries)
    }
}
