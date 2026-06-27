//
//  PermissionService.swift
//  Spitr
//
//  Reads and requests the three permissions Spitr needs, each for a clear reason:
//  • Microphone  — to capture audio while the key is held
//  • Speech      — for on-device transcription (Apple engine)
//  • Accessibility — to receive the global hotkey and paste into other apps
//

import AppKit
import AVFoundation
import Speech

private let log = DiagLog(category: "permissions")

enum PermissionState: Equatable {
    case granted
    case denied
    case notDetermined
}

final class PermissionService {

    // MARK: - Current state

    var microphone: PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:       return .granted
        case .denied, .restricted: return .denied
        case .notDetermined:    return .notDetermined
        @unknown default:       return .denied
        }
    }

    var speech: PermissionState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:       return .granted
        case .denied, .restricted: return .denied
        case .notDetermined:    return .notDetermined
        @unknown default:       return .denied
        }
    }

    /// Accessibility is all-or-nothing and only the user can grant it in System Settings.
    var accessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    // MARK: - Requests

    @discardableResult
    func requestMicrophone() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        log.info("microphone request → \(granted ? "granted" : "denied")")
        return granted
    }

    @discardableResult
    func requestSpeech() async -> Bool {
        let granted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        log.info("speech request → \(granted ? "granted" : "denied")")
        return granted
    }

    /// Shows the system Accessibility prompt (only effective while not yet trusted).
    func promptAccessibility() {
        log.info("accessibility prompt shown (trusted: \(self.accessibilityTrusted))")
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
