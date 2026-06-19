//
//  WhisperKitEngine.swift
//  Spitr
//
//  TranscriptionEngine backed by WhisperKit (on-device Whisper, ANE-accelerated).
//  Fallback / quality option for older Macs and best German accuracy.
//
//  NOTE: the CoreML model is downloaded once from Hugging Face on first prepare()
//  and cached locally; every transcription afterwards runs fully on-device.
//

import Foundation
import WhisperKit
import os

private let log = Logger(subsystem: "com.jarek.Spitr", category: "whisperkit")

final class WhisperKitEngine: TranscriptionEngine {
    let id = "whisperkit"
    let displayName = "WhisperKit"

    /// Default model: a good speed/accuracy trade-off and a modest download.
    /// A model picker (ModelManager) can override this later.
    private let model: String

    private var pipe: WhisperKit?

    init(model: String = "base") {
        self.model = model
    }

    var isAvailable: Bool {
        // The framework is present; CoreML runs on Apple Silicon and Intel
        // (slower). Real availability is proven once prepare() loads the model.
        true
    }

    func prepare() async throws {
        guard pipe == nil else { return }
        do {
            // Downloads the model on first run, then loads + prewarms it.
            let config = WhisperKitConfig(model: model)
            pipe = try await WhisperKit(config)
            log.info("WhisperKit ready (model: \(self.model, privacy: .public))")
        } catch {
            throw TranscriptionError.underlying(error)
        }
    }

    func transcribe(_ audio: AudioBuffer, locale: Locale) async throws -> String {
        guard !audio.samples.isEmpty else { throw TranscriptionError.empty }
        guard let pipe else { throw TranscriptionError.notPrepared }

        // WhisperKit expects 16 kHz mono Float — exactly what AudioCaptureService
        // produces. Pass the language hint when known, else let it auto-detect.
        let options = DecodingOptions(
            task: .transcribe,
            language: locale.language.languageCode?.identifier
        )

        do {
            let results = try await pipe.transcribe(audioArray: audio.samples,
                                                     decodeOptions: options)
            let text = results.map(\.text).joined(separator: " ")
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw TranscriptionError.underlying(error)
        }
    }
}
