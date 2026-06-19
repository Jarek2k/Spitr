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

    @Published private(set) var state: State = .idle

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

    private let settings: SettingsStore
    private let history: HistoryStore
    private let hotkey: HotkeyService
    private let audio = AudioCaptureService()
    private let insertion = TextInsertionService()
    private let media = MediaPlaybackController()
    private let selector = EngineSelector()
    private var engine: TranscriptionEngine
    private var enginePrepared = false

    private var overlay: OverlayController?
    private var levelTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var activated = false

    init(settings: SettingsStore, history: HistoryStore) {
        self.settings = settings
        self.history = history
        let hotkey = HotkeyService(config: HotkeyConfig.named(keyCode: settings.hotkeyKeyCode))
        self.hotkey = hotkey
        self.engine = selector.makeEngine(settings.engineKind, whisperModel: settings.whisperModel)

        audio.preferredDeviceUID = settings.inputDeviceUID

        hotkey.onPress = { [weak self] in self?.startRecording() }
        hotkey.onRelease = { [weak self] in self?.finishRecording() }

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

        // Apply a new mic choice on the next recording.
        settings.$inputDeviceUID
            .dropFirst()
            .sink { [weak self] uid in self?.audio.preferredDeviceUID = uid }
            .store(in: &cancellables)
    }

    /// Rebuilds the transcription engine from current settings. Prepare() is
    /// deferred to the next recording, so switching engines/models is cheap.
    private func rebuildEngine() {
        engine = selector.makeEngine(settings.engineKind, whisperModel: settings.whisperModel)
        enginePrepared = false
    }

    /// Called once at launch: begin listening for the hotkey and read permissions.
    func activate() {
        guard !activated else { return }
        activated = true
        hotkey.start()
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

    private func startRecording() {
        guard state == .idle else { return }
        do {
            try audio.start()
            media.pauseIfPlaying()
            inputLevel = 0
            sessionID += 1
            state = .recording
        } catch {
            state = .error(error.localizedDescription)
            scheduleIdleReset()
        }
    }

    private func finishRecording() {
        guard state == .recording else { return }
        inputLevel = 0
        state = .transcribing

        Task {
            // Keep capturing briefly so trailing audio (input latency) isn't
            // clipped when the key is released right after the last word.
            try? await Task.sleep(for: .milliseconds(180))
            let buffer = audio.stop()
            media.resumeIfPaused()
            log.info("captured \(buffer.samples.count) samples @ \(buffer.sampleRate) Hz")
            do {
                if !enginePrepared {
                    try await engine.prepare()
                    enginePrepared = true
                }
                let text = try await engine.transcribe(buffer, locale: settings.locale)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    insertion.insert(trimmed)
                    history.record(trimmed)
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

    private func scheduleIdleReset() {
        Task {
            try? await Task.sleep(for: .seconds(2))
            if case .error = state { state = .idle }
        }
    }

    // MARK: - UI helpers

    var menuBarSymbol: String {
        switch state {
        case .idle:         return "mic"
        case .recording:    return "mic.fill"
        case .transcribing: return "waveform"
        case .error:        return "exclamationmark.triangle"
        }
    }

    var statusText: String {
        switch state {
        case .idle:         return "Bereit"
        case .recording:    return "Aufnahme läuft…"
        case .transcribing: return "Wandle um…"
        case .error(let m): return "Fehler: \(m)"
        }
    }

    var allPermissionsGranted: Bool {
        micGranted && speechGranted && accessibilityTrusted
    }
}
