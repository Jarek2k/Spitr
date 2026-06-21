//
//  RecordingController.swift
//  Spitr
//
//  The state machine that ties the pieces together:
//  hotkey held → capture audio → release → transcribe → insert text.
//  Owns app-wide state for the menu bar UI.
//

import Foundation
import AppKit
import Combine
import os

private let log = Logger(subsystem: "com.jarek.Spitr", category: "recording")

@MainActor
final class RecordingController: ObservableObject {

    enum State: Equatable {
        case idle
        case recording
        case transcribing
        case error(String)
    }

    enum Mode { case dictation, command }

    @Published private(set) var state: State = .idle

    /// Whether the in-flight recording is a voice command (Shift held) rather
    /// than dictation. Drives the overlay's appearance.
    @Published private(set) var mode: Mode = .dictation

    /// Short confirmation of the last voice command, shown briefly in the
    /// overlay then cleared.
    @Published private(set) var commandFeedback: String?

    /// Whether the last command was recognized (drives the feedback icon).
    @Published private(set) var lastCommandRecognized = false

    /// The most recent dictation we inserted, kept independently of the (optional)
    /// history so "re-insert last" works even with history recording switched off.
    /// nil disables the menu action.
    @Published private(set) var lastInsertedText: String?

    /// Mirrors `settings.isPaused` so the menu/status update reactively.
    @Published private(set) var paused = false

    /// Latest normalized input level (0…1), driven by the audio tap and consumed
    /// by the recording overlay's waveform.
    @Published private(set) var inputLevel: Float = 0

    /// Increments on each recording start so the waveform resets its history.
    @Published private(set) var sessionID = 0

    // Permission state, refreshed for the menu.
    @Published private(set) var micGranted = false
    @Published private(set) var speechGranted = false
    @Published private(set) var accessibilityTrusted = false

    let permissions = PermissionService()

    /// Current Hold-to-Talk key, derived from settings for the menu hint.
    var hotkeyConfig: HotkeyConfig { HotkeyConfig.named(keyCode: settings.hotkeyKeyCode) }

    /// Display string of the re-insert chord, for the menu hint.
    var reinsertShortcutLabel: String { settings.reinsertShortcut.displayString }

    /// Shared preferences; exposed so the overlay can observe the waveform style.
    let settings: SettingsStore
    private let history: HistoryStore
    private let dictionary: DictionaryStore
    private let replacement: TextReplacing = TextReplacementService()
    private let interpreter = VoiceCommandInterpreter()
    private let hotkey: HotkeyService
    private let audio = AudioCaptureService()
    private let insertion = TextInsertionService()
    private let feedback = FeedbackSoundService()
    private let selector = EngineSelector()
    private var engine: TranscriptionEngine
    private var enginePrepared = false
    /// In-flight prepare(), so a proactive prewarm and a recording that needs the
    /// engine share one load instead of racing into two concurrent inits.
    private var prepareTask: Task<Void, Error>?

    private var overlay: OverlayController?
    private var levelTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var activated = false

    /// The last non-Spitr app that was frontmost, so a menu-triggered re-insert
    /// can hand focus back to it before pasting (opening our menu takes focus).
    private var lastExternalApp: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?

    init(settings: SettingsStore, history: HistoryStore, dictionary: DictionaryStore) {
        self.settings = settings
        self.history = history
        self.dictionary = dictionary
        let hotkey = HotkeyService(config: HotkeyConfig.named(keyCode: settings.hotkeyKeyCode))
        self.hotkey = hotkey
        self.engine = selector.makeEngine(settings.engineKind, whisperModel: settings.whisperModel)

        audio.preferredDeviceUID = settings.inputDeviceUID

        hotkey.onPress = { [weak self] command in self?.startRecording(command: command) }
        hotkey.onRelease = { [weak self] in self?.finishRecording() }
        hotkey.onCancel = { [weak self] in self?.cancelRecording() }
        hotkey.onReinsert = { [weak self] in self?.reinsertLast() }
        hotkey.updateReinsert(settings.reinsertShortcut)
        insertion.smartSpacing = settings.smartSpacing

        // Chime the moment the mic is genuinely capturing, so the user knows when
        // to speak and doesn't clip the first word.
        audio.onCaptureStarted = { [weak self] in
            guard let self, self.settings.playReadyChime else { return }
            self.feedback.playReady()
        }

        // Rebuild the engine when the override or WhisperKit model changes;
        // defer prepare() to the next recording so switching is cheap.
        settings.$engineKind
            .dropFirst()
            .sink { [weak self] _ in self?.rebuildEngine() }
            .store(in: &cancellables)
        settings.$whisperModel
            .dropFirst()
            .sink { [weak self] _ in self?.rebuildEngine() }
            .store(in: &cancellables)

        // Swap the Hold-to-Talk key live when changed in Settings.
        settings.$hotkeyKeyCode
            .dropFirst()
            .sink { [weak self] code in
                self?.hotkey.update(config: HotkeyConfig.named(keyCode: code))
            }
            .store(in: &cancellables)

        // Swap the re-insert chord live when changed in Settings.
        settings.$reinsertShortcut
            .dropFirst()
            .sink { [weak self] combo in self?.hotkey.updateReinsert(combo) }
            .store(in: &cancellables)

        // Apply the smart-spacing toggle live.
        settings.$smartSpacing
            .dropFirst()
            .sink { [weak self] on in self?.insertion.smartSpacing = on }
            .store(in: &cancellables)

        // Apply a new mic choice on the next recording.
        settings.$inputDeviceUID
            .dropFirst()
            .sink { [weak self] uid in self?.audio.preferredDeviceUID = uid }
            .store(in: &cancellables)

        // Mirror pause state (toggled from menu or by voice command).
        settings.$isPaused
            .sink { [weak self] in self?.paused = $0 }
            .store(in: &cancellables)
    }

    /// Toggles pause; while paused, plain dictation is ignored but command mode
    /// still works so the user can resume by voice.
    func togglePause() { settings.isPaused.toggle() }

    /// Whether there's a recorded dictation to correct (drives the menu item).
    var canCorrectHistory: Bool { !history.entries.isEmpty }

    /// Routes the Settings window to the Verlauf tab and asks it to start
    /// correcting the most recent dictation. The menu opens Settings alongside.
    func beginCorrectLastDictation() {
        guard let latest = history.entries.first else { return }
        settings.requestedTab = .history
        settings.pendingCorrectionID = latest.id
    }

    /// Re-inserts the last dictation into the currently intended field — recovery
    /// for when the original insert went to the wrong place. Opening our menu
    /// stole key focus, so hand it back to the previous app before pasting.
    func reinsertLast() {
        guard let text = lastInsertedText else { return }
        let target = lastExternalApp
        Task { @MainActor in
            target?.activate()
            // Give the app a beat to become frontmost and restore its first
            // responder before the synthetic Cmd+V lands.
            try? await Task.sleep(for: .milliseconds(150))
            insertion.insert(text)
            log.info("re-inserted last dictation (\(text.count) chars)")
        }
    }

    /// Rebuilds the transcription engine from current settings and proactively
    /// prewarms it, so the model load happens while the user is still in Settings
    /// rather than stalling the first recording after a switch.
    private func rebuildEngine() {
        // Abandon any in-flight load for the engine we're replacing, so a heavy
        // model (e.g. large-v3) doesn't keep churning after the user switches away.
        prepareTask?.cancel()
        engine = selector.makeEngine(settings.engineKind, whisperModel: settings.whisperModel)
        enginePrepared = false
        prepareTask = nil
        Task { try? await ensurePrepared() }
    }

    /// Loads the engine model once, deduplicating concurrent callers (prewarm vs.
    /// an actual recording) onto a single in-flight prepare().
    private func ensurePrepared() async throws {
        if enginePrepared { return }
        if let task = prepareTask {
            try await task.value
            return
        }
        let engine = self.engine
        let task = Task { try await engine.prepare() }
        prepareTask = task
        do {
            try await task.value
            enginePrepared = true
        } catch {
            prepareTask = nil
            throw error
        }
    }

    /// Called once at launch: begin listening for the hotkey and read permissions.
    func activate() {
        guard !activated else { return }
        activated = true
        hotkey.start()
        // Prewarm the engine at launch so the first dictation doesn't stall on a
        // cold model load (later engine/model switches already prewarm via rebuild).
        Task { try? await ensurePrepared() }
        // Track the frontmost non-Spitr app so re-insert can restore its focus.
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            MainActor.assumeIsolated { self?.lastExternalApp = app }
        }
        refreshPermissions()
        overlay = OverlayController(controller: self)
        levelTask = Task { [weak self] in
            guard let levels = self?.audio.levels else { return }
            for await level in levels {
                self?.inputLevel = level
            }
        }
    }

    func refreshPermissions() {
        micGranted = permissions.microphone == .granted
        speechGranted = permissions.speech == .granted
        accessibilityTrusted = permissions.accessibilityTrusted
    }

    func requestMicrophone() {
        Task {
            await permissions.requestMicrophone()
            refreshPermissions()
        }
    }

    func requestSpeech() {
        Task {
            await permissions.requestSpeech()
            refreshPermissions()
        }
    }

    func openAccessibility() {
        permissions.promptAccessibility()
        permissions.openAccessibilitySettings()
    }

    // MARK: - Recording lifecycle

    private func startRecording(command: Bool = false) {
        guard state == .idle else { return }
        // While paused, ignore dictation — but command mode still works so the
        // user can say "weiter" to resume.
        guard command || !settings.isPaused else { return }
        mode = command ? .command : .dictation
        commandFeedback = nil
        do {
            try audio.start()
            inputLevel = 0
            sessionID += 1
            state = .recording
            // Listen for Escape so the user can abort this recording.
            hotkey.beginCancelWatch()
        } catch {
            state = .error(error.localizedDescription)
            scheduleIdleReset()
        }
    }

    /// Aborts the in-flight recording: discard the audio, transcribe nothing,
    /// insert nothing. Triggered by Escape while holding the record key.
    private func cancelRecording() {
        guard state == .recording else { return }
        hotkey.endCancelWatch()
        _ = audio.stop()
        inputLevel = 0
        mode = .dictation
        state = .idle
        log.info("recording cancelled (Esc)")
    }

    private func finishRecording() {
        guard state == .recording else { return }
        hotkey.endCancelWatch()
        inputLevel = 0
        state = .transcribing

        Task {
            // Keep capturing briefly so trailing audio (input latency) isn't
            // clipped when the key is released right after the last word.
            try? await Task.sleep(for: .milliseconds(180))
            let buffer = audio.stop()
            log.info("captured \(buffer.samples.count) samples @ \(buffer.sampleRate) Hz")
            do {
                try await ensurePrepared()
                let text = try await engine.transcribe(buffer, locale: settings.locale, vocabulary: settings.vocabulary)
                if mode == .command {
                    handleCommand(text)
                    state = .idle
                    return
                }
                let corrected = replacement.apply(dictionary.activeRules, to: text)
                let trimmed = corrected.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    insertion.insert(trimmed)
                    history.record(trimmed)
                    lastInsertedText = trimmed
                    if settings.playDoneChime { feedback.playDone() }
                    log.info("inserted transcript (\(trimmed.count) chars)")
                } else {
                    log.warning("empty transcript, nothing inserted")
                }
                state = .idle
            } catch {
                log.error("transcription failed: \(error.localizedDescription, privacy: .public)")
                state = .error(error.localizedDescription)
                scheduleIdleReset()
            }
        }
    }

    /// Matches a spoken transcript to a voice command and applies it, surfacing
    /// a short confirmation in the overlay either way.
    private func handleCommand(_ transcript: String) {
        if let command = interpreter.match(transcript,
                                           settings: settings,
                                           history: history,
                                           dictionary: dictionary) {
            command.perform()
            log.info("voice command: \(command.id, privacy: .public)")
            lastCommandRecognized = true
            showCommandFeedback(command.title)
        } else {
            log.info("voice command not recognized")
            lastCommandRecognized = false
            showCommandFeedback(String(localized: "Befehl nicht erkannt"))
        }
    }

    private func showCommandFeedback(_ text: String) {
        commandFeedback = text
        Task {
            try? await Task.sleep(for: .milliseconds(1600))
            if commandFeedback == text { commandFeedback = nil }
        }
    }

    private func scheduleIdleReset() {
        Task {
            try? await Task.sleep(for: .seconds(2))
            if case .error = state { state = .idle }
        }
    }

    // MARK: - UI helpers

    var menuBarSymbol: String {
        if paused, state == .idle { return "pause.circle" }
        switch state {
        case .idle:         return "mic"
        case .recording:    return mode == .command ? "command.circle.fill" : "mic.fill"
        case .transcribing: return "waveform"
        case .error:        return "exclamationmark.triangle"
        }
    }

    var statusText: String {
        if paused, state == .idle { return String(localized: "Pausiert") }
        switch state {
        case .idle:         return String(localized: "Bereit")
        case .recording:    return mode == .command ? String(localized: "Befehl…") : String(localized: "Aufnahme läuft…")
        case .transcribing: return String(localized: "Wird umgewandelt…")
        case .error(let m): return String(localized: "Fehler: \(m)")
        }
    }

    /// Human-readable label for the engine/model in use, so the menu can show
    /// exactly what's active (e.g. "WhisperKit · large-v3") — no guessing after
    /// a switch.
    var activeEngineLabel: String {
        switch settings.engineKind {
        case .apple:      return EngineKind.apple.displayName
        case .whisperKit: return "\(EngineKind.whisperKit.displayName) · \(settings.whisperModel)"
        }
    }

    var allPermissionsGranted: Bool {
        micGranted && speechGranted && accessibilityTrusted
    }

    /// True when the overlay should show a bare, chrome-free animation — no
    /// capsule, no mic glyph (strands and KITT). Only for plain dictation.
    var overlayIsChromeless: Bool {
        (settings.waveformStyle == .strands || settings.waveformStyle == .kitt)
            && mode == .dictation && commandFeedback == nil
    }
}
