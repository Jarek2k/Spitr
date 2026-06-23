//
//  EngineSelector.swift
//  Spitr
//
//  Chooses which TranscriptionEngine to use. Apple Speech is the default;
//  WhisperKit is a manually selectable quality option (better accuracy), not a
//  compatibility fallback. Callers depend on the protocol only.
//

import Foundation
import os

private let log = Logger(subsystem: "com.jarek.Spitr", category: "engine")

enum EngineKind: String, CaseIterable, Identifiable {
    case apple
    case whisperKit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple:      return "Apple Speech"
        case .whisperKit: return "WhisperKit"
        }
    }
}

final class EngineSelector {
    /// Builds the engine for a given kind. Falls back to Apple if a kind is
    /// not yet implemented or unavailable on this device.
    func makeEngine(_ kind: EngineKind, whisperModel: String = WhisperKitEngine.defaultModel) -> TranscriptionEngine {
        switch kind {
        case .apple:
            log.info("building engine: Apple Speech")
            return AppleSpeechEngine()
        case .whisperKit:
            log.info("building engine: WhisperKit (model: \(whisperModel, privacy: .public))")
            return WhisperKitEngine(model: whisperModel)
        }
    }

    /// Sensible default for the current hardware. Apple Silicon + modern macOS
    /// → Apple Speech (zero download). Expand once WhisperKit lands.
    func defaultKind() -> EngineKind {
        .apple
    }
}
