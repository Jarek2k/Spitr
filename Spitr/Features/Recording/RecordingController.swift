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
    @Published var locale: Locale = Locale(identifier: "de-DE")

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
    let hotkeyConfig: HotkeyConfig

    private let hotkey: HotkeyService
    private let audio = AudioCaptureService()
    private let insertion = TextInsertionService()
    private let selector = EngineSelector()
    private let engine: TranscriptionEngine
    private var enginePrepared = false

    private var overlay: OverlayController?
    private var levelTask: Task<Void, Never>?
    private var activated = false

    init() {
        let hotkey = HotkeyService()
        self.hotkey = hotkey
        self.hotkeyConfig = hotkey.config
        self.engine = selector.makeEngine(selector.defaultKind())

        hotkey.onPress = { [weak self] in self?.startRecording() }
        hotkey.onRelease = { [weak self] in self?.finishRecording() }
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
        let buffer = audio.stop()
        inputLevel = 0
        state = .transcribing
        log.info("captured \(buffer.samples.count) samples @ \(buffer.sampleRate) Hz")

        Task {
            do {
                if !enginePrepared {
                    try await engine.prepare()
                    enginePrepared = true
                }
                let text = try await engine.transcribe(buffer, locale: locale)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    insertion.insert(trimmed)
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
