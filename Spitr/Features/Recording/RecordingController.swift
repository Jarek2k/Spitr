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
        hotkey.start()
        refreshPermissions()
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
            state = .recording
        } catch {
            state = .error(error.localizedDescription)
            scheduleIdleReset()
        }
    }

    private func finishRecording() {
        guard state == .recording else { return }
        let buffer = audio.stop()
        state = .transcribing

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
                }
                state = .idle
            } catch {
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
