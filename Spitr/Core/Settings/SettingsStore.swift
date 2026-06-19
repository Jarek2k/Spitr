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

    /// Virtual key code of the Hold-to-Talk key (see HotkeyConfig.selectable).
    @Published var hotkeyKeyCode: UInt16 {
        didSet { defaults.set(Int(hotkeyKeyCode), forKey: Keys.hotkey) }
    }

    /// WhisperKit model name (e.g. "base", "small", "large-v3"). Only relevant
    /// when the WhisperKit engine is selected.
    @Published var whisperModel: String {
        didSet { defaults.set(whisperModel, forKey: Keys.whisperModel) }
    }

    /// UID of the chosen input device. Empty string → system default mic.
    @Published var inputDeviceUID: String {
        didSet { defaults.set(inputDeviceUID, forKey: Keys.inputDevice) }
    }

    /// Set once the user has seen the permission onboarding, so it shows only
    /// on first launch.
    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }

    var locale: Locale { Locale(identifier: localeIdentifier) }

    private let defaults: UserDefaults

    private enum Keys {
        static let engine = "engineKind"
        static let locale = "localeIdentifier"
        static let hotkey = "hotkeyKeyCode"
        static let whisperModel = "whisperModel"
        static let inputDevice = "inputDeviceUID"
        static let onboarding = "hasCompletedOnboarding"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Keys.engine) ?? EngineKind.apple.rawValue
        self.engineKind = EngineKind(rawValue: raw) ?? .apple
        self.localeIdentifier = defaults.string(forKey: Keys.locale) ?? "de-DE"
        let storedHotkey = defaults.object(forKey: Keys.hotkey) as? Int
        self.hotkeyKeyCode = storedHotkey.map(UInt16.init) ?? HotkeyConfig.rightOption.keyCode
        self.whisperModel = defaults.string(forKey: Keys.whisperModel) ?? WhisperKitEngine.defaultModel
        self.inputDeviceUID = defaults.string(forKey: Keys.inputDevice) ?? ""
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
    }
}
