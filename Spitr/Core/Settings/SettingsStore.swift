//
//  SettingsStore.swift
//  Spitr
//
//  User-facing preferences, persisted in UserDefaults. The single source of
//  truth for engine override and recognition language; the RecordingController
//  observes it and the SettingsView edits it.
//

import Foundation
import Combine

@MainActor
final class SettingsStore: ObservableObject {

    /// Manual engine override. Defaults to Apple Speech (zero download).
    @Published var engineKind: EngineKind {
        didSet { defaults.set(engineKind.rawValue, forKey: Keys.engine) }
    }

    /// BCP-47 identifier of the recognition language, e.g. "de-DE".
    @Published var localeIdentifier: String {
        didSet { defaults.set(localeIdentifier, forKey: Keys.locale) }
    }

    var locale: Locale { Locale(identifier: localeIdentifier) }

    private let defaults: UserDefaults

    private enum Keys {
        static let engine = "engineKind"
        static let locale = "localeIdentifier"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Keys.engine) ?? EngineKind.apple.rawValue
        self.engineKind = EngineKind(rawValue: raw) ?? .apple
        self.localeIdentifier = defaults.string(forKey: Keys.locale) ?? "de-DE"
    }
}
