//
//  AppleSpeechEngine.swift
//  Spitr
//
//  TranscriptionEngine backed by SFSpeechRecognizer (macOS 13+).
//  On macOS 26 we may swap to SpeechAnalyzer / SpeechTranscriber later.
//

import Foundation
import Speech
import AVFoundation

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
            break
        case .denied, .restricted, .notDetermined:
            throw TranscriptionError.permissionDenied
        @unknown default:
            throw TranscriptionError.permissionDenied
        }
    }

    func transcribe(_ audio: AudioBuffer, locale: Locale) async throws -> String {
        guard !audio.samples.isEmpty else { throw TranscriptionError.empty }

        let recognizer = try resolveRecognizer(for: locale)
        guard recognizer.isAvailable else { throw TranscriptionError.engineUnavailable }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false
        // Force on-device — no network calls in MVP.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        guard let pcm = Self.makePCMBuffer(from: audio) else {
            throw TranscriptionError.empty
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let resumer = ResumeOnce(continuation: continuation)
            let task = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    resumer.fail(TranscriptionError.underlying(error))
                    return
                }
                guard let result, result.isFinal else { return }
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
            throw TranscriptionError.localeUnsupported(locale)
        }
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
