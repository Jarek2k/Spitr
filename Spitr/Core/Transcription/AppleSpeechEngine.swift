//
//  AppleSpeechEngine.swift
//  Spitr
//
//  TranscriptionEngine backed by SFSpeechRecognizer, on-device.
//  Could move to SpeechAnalyzer / SpeechTranscriber later (macOS 26 baseline).
//

import Foundation
import Speech
import AVFoundation

private let log = DiagLog(category: "applespeech")

final class AppleSpeechEngine: TranscriptionEngine {
    let id = "apple"
    let displayName = "Apple Speech"

    var isAvailable: Bool {
        // Authorization is required at runtime, but the framework itself is always present on macOS 13+.
        SFSpeechRecognizer.authorizationStatus() != .restricted
    }

    private var recognizer: SFSpeechRecognizer?
    private var preparedLocale: Locale?

    func prepare() async throws {
        let status = await Self.requestAuthorization()
        switch status {
        case .authorized:
            log.info("ready (speech authorization granted)")
        case .denied, .restricted, .notDetermined:
            log.error("speech authorization not granted (status: \(status.rawValue))")
            throw TranscriptionError.permissionDenied
        @unknown default:
            log.error("speech authorization unknown (status: \(status.rawValue))")
            throw TranscriptionError.permissionDenied
        }
    }

    func transcribe(_ audio: AudioBuffer, locale: Locale, vocabulary: [String]) async throws -> String {
        guard !audio.samples.isEmpty else { throw TranscriptionError.empty }

        let recognizer = try resolveRecognizer(for: locale)
        guard recognizer.isAvailable else {
            log.error("recognizer unavailable for locale \(locale.identifier)")
            throw TranscriptionError.engineUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false
        // Bias recognition toward the user's custom terms (names, jargon).
        if !vocabulary.isEmpty {
            request.contextualStrings = vocabulary
        }
        // Force on-device — no network calls in MVP.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        guard let pcm = Self.makePCMBuffer(from: audio) else {
            throw TranscriptionError.empty
        }

        let audioSec = Double(audio.samples.count) / audio.sampleRate
        let onDevice = request.requiresOnDeviceRecognition
        let t0 = Date()
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let resumer = ResumeOnce(continuation: continuation)
            let task = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    log.error("transcribe failed after \(Int(Date().timeIntervalSince(t0) * 1000)) ms: \(error.localizedDescription)")
                    resumer.fail(TranscriptionError.underlying(error))
                    return
                }
                guard let result, result.isFinal else { return }
                let ms = Int(Date().timeIntervalSince(t0) * 1000)
                log.info("transcribe \(String(format: "%.1f", audioSec))s audio in \(ms) ms (onDevice: \(onDevice), chars: \(result.bestTranscription.formattedString.count))")
                resumer.succeed(result.bestTranscription.formattedString)
            }
            _ = task // retained by Speech framework while the task runs
            request.append(pcm)
            request.endAudio()
        }
    }

    private func resolveRecognizer(for locale: Locale) throws -> SFSpeechRecognizer {
        if let recognizer, preparedLocale == locale { return recognizer }
        guard let r = SFSpeechRecognizer(locale: locale) else {
            log.error("locale unsupported: \(locale.identifier)")
            throw TranscriptionError.localeUnsupported(locale)
        }
        log.info("recognizer resolved for locale \(locale.identifier)")
        self.recognizer = r
        self.preparedLocale = locale
        return r
    }

    private static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
    }

    private static func makePCMBuffer(from audio: AudioBuffer) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: audio.sampleRate,
                                         channels: 1,
                                         interleaved: false) else { return nil }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(audio.samples.count)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(audio.samples.count)
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        audio.samples.withUnsafeBufferPointer { src in
            if let base = src.baseAddress {
                channel.update(from: base, count: src.count)
            }
        }
        return buffer
    }
}

/// Guarantees a CheckedContinuation is resumed exactly once, even when the
/// underlying callback may fire both "error" and "isFinal" paths.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    private let continuation: CheckedContinuation<String, Error>

    init(continuation: CheckedContinuation<String, Error>) {
        self.continuation = continuation
    }

    func succeed(_ value: String) {
        lock.lock(); defer { lock.unlock() }
        guard !done else { return }
        done = true
        continuation.resume(returning: value)
    }

    func fail(_ error: Error) {
        lock.lock(); defer { lock.unlock() }
        guard !done else { return }
        done = true
        continuation.resume(throwing: error)
    }
}
