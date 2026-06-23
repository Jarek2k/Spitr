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

/// The Settings window's tabs. Lives here so non-UI code (the controller) can
/// request a specific tab when opening Settings.
enum SettingsTab: String, CaseIterable {
    case general, vocabulary, dictionary, commands, history, diagnostics
}

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

    /// Visual style of the recording overlay's waveform.
    @Published var waveformStyle: WaveformStyle {
        didSet { defaults.set(waveformStyle.rawValue, forKey: Keys.waveform) }
    }

    /// Route mic input through Apple's voice-processing I/O (noise suppression,
    /// echo cancellation, automatic gain). On by default — helps with mumbling
    /// and background noise; can be turned off if it hurts in a quiet room.
    @Published var voiceIsolation: Bool {
        didSet { defaults.set(voiceIsolation, forKey: Keys.voiceIsolation) }
    }

    /// Global chord that re-inserts the last dictation. Persisted as JSON.
    @Published var reinsertShortcut: KeyCombo {
        didSet {
            if let data = try? JSONEncoder().encode(reinsertShortcut) {
                defaults.set(data, forKey: Keys.reinsert)
            }
        }
    }

    /// Custom recognition vocabulary, one term per line. Fed to the engine as a
    /// bias hint so names/jargon aren't misheard.
    @Published var vocabularyText: String {
        didSet { defaults.set(vocabularyText, forKey: Keys.vocabulary) }
    }

    /// Non-empty, trimmed vocabulary terms.
    var vocabulary: [String] {
        vocabularyText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Play a short chime the moment the mic is actually capturing, so the user
    /// knows when to start speaking and doesn't clip the first word.
    @Published var playReadyChime: Bool {
        didSet { defaults.set(playReadyChime, forKey: Keys.readyChime) }
    }

    /// Which ready cue to play (single blip, double beep, rising PTT tone).
    @Published var readyChimeStyle: ReadyChimeStyle {
        didSet { defaults.set(readyChimeStyle.rawValue, forKey: Keys.readyChimeStyle) }
    }

    /// Play a short chime once the transcript has been inserted, so the wait
    /// during transcription has an audible end.
    @Published var playDoneChime: Bool {
        didSet { defaults.set(playDoneChime, forKey: Keys.doneChime) }
    }

    /// Normalize spacing on insert and add a leading space when the text would
    /// otherwise stick to the preceding word.
    @Published var smartSpacing: Bool {
        didSet { defaults.set(smartSpacing, forKey: Keys.smartSpacing) }
    }

    /// Set once the user has seen the permission onboarding, so it shows only
    /// on first launch.
    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }

    /// Write a richer diagnostic log (adds periodic memory/thread samples).
    /// Off by default — the plain log already captures errors and timings.
    @Published var verboseLogging: Bool {
        didSet { defaults.set(verboseLogging, forKey: Keys.verboseLogging) }
    }

    /// Transient (not persisted): when paused, dictation is ignored until
    /// resumed. Command mode still works, so it can be toggled by voice.
    @Published var isPaused: Bool = false

    /// Transient: which tab the Settings window shows. Set before opening Settings
    /// (e.g. from the menu's "correct last dictation") so it lands on the right tab.
    @Published var requestedTab: SettingsTab = .general

    /// Transient: a history entry id the Verlauf tab should start correcting once
    /// it appears. Consumed (cleared) by the view after presenting the sheet.
    @Published var pendingCorrectionID: UUID?

    var locale: Locale { Locale(identifier: localeIdentifier) }

    private let defaults: UserDefaults

    private enum Keys {
        static let engine = "engineKind"
        static let locale = "localeIdentifier"
        static let hotkey = "hotkeyKeyCode"
        static let whisperModel = "whisperModel"
        static let inputDevice = "inputDeviceUID"
        static let onboarding = "hasCompletedOnboarding"
        static let waveform = "waveformStyle"
        static let vocabulary = "vocabularyText"
        static let readyChime = "playReadyChime"
        static let readyChimeStyle = "readyChimeStyle"
        static let doneChime = "playDoneChime"
        static let reinsert = "reinsertShortcut"
        static let smartSpacing = "smartSpacing"
        static let verboseLogging = "verboseLogging"
        static let voiceIsolation = "voiceIsolation"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Keys.engine) ?? EngineKind.apple.rawValue
        self.engineKind = EngineKind(rawValue: raw) ?? .apple
        self.localeIdentifier = defaults.string(forKey: Keys.locale) ?? "de-DE"
        let storedHotkey = defaults.object(forKey: Keys.hotkey) as? Int
        self.hotkeyKeyCode = storedHotkey.map(UInt16.init) ?? HotkeyConfig.rightOption.keyCode
        // Fall back to the default if the stored model id is no longer offered
        // (e.g. a removed/renamed model that WhisperKit can't resolve anymore).
        let storedModel = defaults.string(forKey: Keys.whisperModel) ?? WhisperKitEngine.defaultModel
        self.whisperModel = WhisperKitEngine.isSelectable(storedModel) ? storedModel : WhisperKitEngine.defaultModel
        self.inputDeviceUID = defaults.string(forKey: Keys.inputDevice) ?? ""
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        self.verboseLogging = defaults.bool(forKey: Keys.verboseLogging)
        self.playReadyChime = defaults.object(forKey: Keys.readyChime) as? Bool ?? true
        let chimeStyleRaw = defaults.string(forKey: Keys.readyChimeStyle) ?? ReadyChimeStyle.double.rawValue
        self.readyChimeStyle = ReadyChimeStyle(rawValue: chimeStyleRaw) ?? .double
        self.playDoneChime = defaults.object(forKey: Keys.doneChime) as? Bool ?? true
        self.smartSpacing = defaults.object(forKey: Keys.smartSpacing) as? Bool ?? true
        // Off by default: voice processing is VoIP echo-cancellation tech that
        // builds an internal mic+output aggregate device, which is fragile and
        // currently regressed on macOS 26 (errs -10876/-10877). One-way dictation
        // doesn't need echo cancellation; its only real upside here is noise
        // suppression, so it stays an opt-in experiment.
        self.voiceIsolation = defaults.object(forKey: Keys.voiceIsolation) as? Bool ?? false
        let waveformRaw = defaults.string(forKey: Keys.waveform) ?? WaveformStyle.signalReactive.rawValue
        self.waveformStyle = WaveformStyle(rawValue: waveformRaw) ?? .signalReactive
        self.vocabularyText = defaults.string(forKey: Keys.vocabulary) ?? ""
        if let data = defaults.data(forKey: Keys.reinsert),
           let combo = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            self.reinsertShortcut = combo
        } else {
            self.reinsertShortcut = .reinsertDefault
        }
    }
}
