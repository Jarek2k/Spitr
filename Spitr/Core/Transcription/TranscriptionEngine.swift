//
//  TranscriptionEngine.swift
//  Spitr
//
//  Engine-agnostic boundary for speech-to-text.
//

import Foundation

/// Mono PCM audio buffer used as the universal input across all engines.
/// Float samples in [-1, 1].
struct AudioBuffer: Sendable {
    let samples: [Float]
    let sampleRate: Double

    var duration: TimeInterval {
        Double(samples.count) / sampleRate
    }
}

enum TranscriptionError: Error, LocalizedError {
    case engineUnavailable
    case notPrepared
    case permissionDenied
    case localeUnsupported(Locale)
    case empty
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .engineUnavailable:    return "Speech engine is not available on this device."
        case .notPrepared:          return "Speech engine has not been prepared yet."
        case .permissionDenied:     return "Speech recognition permission was denied."
        case .localeUnsupported(let l): return "Locale \(l.identifier) is not supported by this engine."
        case .empty:                return "No transcribable audio."
        case .underlying(let e):    return e.localizedDescription
        }
    }
}

/// The single seam that hides "which speech engine" from the rest of the app.
/// All callers depend on this protocol — never on a concrete implementation.
protocol TranscriptionEngine: AnyObject {
    /// Stable identifier (e.g. "apple", "whisperkit").
    var id: String { get }

    /// Human-readable name for UI.
    var displayName: String { get }

    /// Whether this engine can run on the current device/OS.
    var isAvailable: Bool { get }

    /// Prewarm / load models. Must be called before `transcribe`.
    func prepare() async throws

    /// Transcribe a finished mono buffer at the buffer's sample rate.
    func transcribe(_ audio: AudioBuffer, locale: Locale) async throws -> String
}
