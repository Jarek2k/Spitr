//
//  AudioCaptureService.swift
//  Spitr
//
//  Captures mic audio while the hotkey is held, resampled to 16 kHz mono Float.
//

import Foundation
import AVFoundation
import CoreAudio
import os

private let log = Logger(subsystem: "com.jarek.Spitr", category: "audio")

enum AudioCaptureError: Error, LocalizedError {
    case formatUnavailable
    case engineFailed(Error)

    var errorDescription: String? {
        switch self {
        case .formatUnavailable:    return "Could not create the target audio format."
        case .engineFailed(let e):  return "AVAudioEngine failed: \(e.localizedDescription)"
        }
    }
}

final class AudioCaptureService: @unchecked Sendable {
    /// Engines like Apple Speech and Whisper expect 16 kHz mono Float PCM.
    static let targetSampleRate: Double = 16_000

    /// Starting guesses for the adaptive level range (dBFS). These self-calibrate
    /// at runtime to whatever mic is in use, so no per-mic tuning is needed.
    static let initialFloorDb: Double = -50
    static let initialPeakDb: Double = -20
    /// Never normalize over less than this span, so ambient noise alone doesn't
    /// drive the meter to full scale when nothing loud has happened.
    static let minRangeDb: Double = 15

    /// Recreated per recording (see start()), so no tap/format/device state
    /// carries over between sessions.
    private var engine = AVAudioEngine()

    /// UID of the microphone to capture from. Empty/nil → system default input.
    /// Set by RecordingController from Settings; applied on the next start().
    var preferredDeviceUID: String?

    /// Fires on the main thread the moment the first buffer is delivered after a
    /// start(), i.e. when the mic is *genuinely* capturing (engine.start()
    /// returns earlier, before hardware warm-up completes). Used to cue the user.
    var onCaptureStarted: (() -> Void)?

    private let lock = NSLock()
    private var samples: [Float] = []
    private var didSignalStart = false

    /// Envelope follower for the level meter: fast attack, slow release, so the
    /// gaps between syllables don't collapse the waveform to a dot.
    private var levelEnvelope: Float = 0

    /// Adaptive loudness range (dBFS), tracked across recordings so the meter
    /// fits any microphone: a slow noise floor and a recent-peak ceiling.
    private var noiseFloorDb: Double = AudioCaptureService.initialFloorDb
    private var peakDb: Double = AudioCaptureService.initialPeakDb

    private var converter: AVAudioConverter?
    private var converterInputFormat: AVAudioFormat?
    private var targetFormat: AVAudioFormat?

    /// 0…1 normalized RMS per processed block. Consumed by the overlay's waveform.
    let levels: AsyncStream<Float>
    private let levelContinuation: AsyncStream<Float>.Continuation

    init() {
        var continuation: AsyncStream<Float>.Continuation!
        self.levels = AsyncStream(bufferingPolicy: .bufferingNewest(8)) { continuation = $0 }
        self.levelContinuation = continuation
    }

    var isRunning: Bool { engine.isRunning }

    func start() throws {
        guard !engine.isRunning else { return }

        // Start from a clean engine every time. A reused engine accumulates state
        // across device switches — most damagingly a tap that survives the engine
        // stopping itself after a HAL error (Bluetooth/USB mic), which then makes
        // the next installTap crash with "nullptr == Tap()". A fresh instance has
        // no tap, no stale format, and re-applies the device pin below.
        engine = AVAudioEngine()

        lock.lock()
        samples.removeAll(keepingCapacity: true)
        didSignalStart = false
        lock.unlock()
        levelEnvelope = 0

        let input = engine.inputNode
        applyPreferredDevice(to: input)

        guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: Self.targetSampleRate,
                                         channels: 1,
                                         interleaved: false) else {
            throw AudioCaptureError.formatUnavailable
        }
        self.targetFormat = target
        // Build the converter lazily from the first tap buffer's *actual* format
        // (see converter(for:)). Reading the node format here is unreliable right
        // after pinning a device — a Bluetooth mic (HFP, 24 kHz) can report a
        // stale rate, and installing the tap with a mismatched explicit format
        // throws an uncatchable ObjC exception. format: nil lets AVAudioEngine use
        // the node's real hardware format, so any sample rate works without a crash.
        self.converter = nil
        self.converterInputFormat = nil

        // Defensive: never install over an existing tap (that throws an
        // uncatchable ObjC exception). A fresh engine has none, but this also
        // covers any reuse path.
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.handleTap(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw AudioCaptureError.engineFailed(error)
        }
    }

    func stop() -> AudioBuffer {
        guard engine.isRunning else {
            return AudioBuffer(samples: [], sampleRate: Self.targetSampleRate)
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        converterInputFormat = nil
        targetFormat = nil

        lock.lock()
        let copy = samples
        samples.removeAll(keepingCapacity: false)
        lock.unlock()

        return AudioBuffer(samples: copy, sampleRate: Self.targetSampleRate)
    }

    /// Pins the engine's input node to the chosen Core Audio device. A nil/empty
    /// UID or an unplugged device leaves the system default in place.
    private func applyPreferredDevice(to input: AVAudioInputNode) {
        guard let uid = preferredDeviceUID, !uid.isEmpty else { return }
        guard let deviceID = AudioDeviceService.deviceID(forUID: uid) else {
            log.warning("preferred mic not found, using system default")
            return
        }
        guard let audioUnit = input.audioUnit else { return }

        var device = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &device,
            UInt32(MemoryLayout<AudioDeviceID>.size))
        if status != noErr {
            log.error("failed to set input device (status \(status)), using default")
        }
    }

    /// Returns a converter from the given hardware format to the 16 kHz target,
    /// rebuilding it only when the input format actually changes (the tap delivers
    /// the same format buffer after buffer, so this is built once per recording).
    private func converter(for inputFormat: AVAudioFormat) -> AVAudioConverter? {
        if let converter, converterInputFormat == inputFormat { return converter }
        guard let targetFormat else { return nil }
        let made = AVAudioConverter(from: inputFormat, to: targetFormat)
        converter = made
        converterInputFormat = inputFormat
        return made
    }

    private func handleTap(_ input: AVAudioPCMBuffer) {
        guard let targetFormat, let converter = converter(for: input.format) else { return }

        let ratio = targetFormat.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio + 1024)
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var error: NSError?
        var consumed = false
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return input
        }
        if status == .error || error != nil { return }
        guard let channel = output.floatChannelData?[0], output.frameLength > 0 else { return }

        let count = Int(output.frameLength)
        let chunk = Array(UnsafeBufferPointer(start: channel, count: count))

        lock.lock()
        samples.append(contentsOf: chunk)
        let firstBuffer = !didSignalStart
        if firstBuffer { didSignalStart = true }
        lock.unlock()

        if firstBuffer, let onCaptureStarted {
            DispatchQueue.main.async(execute: onCaptureStarted)
        }

        var sumSquares: Float = 0
        for s in chunk { sumSquares += s * s }
        let rms = sqrt(sumSquares / Float(count))
        let db = 20 * log10(max(Double(rms), 1e-7))

        // Adaptive gain: the noise floor falls quickly to new quiet and creeps
        // back up slowly; the peak jumps to new loud and decays slowly. The
        // current level is then placed within that self-calibrating range, so
        // loud → near 1 and quiet → near 0 on any microphone.
        noiseFloorDb += (db - noiseFloorDb) * (db < noiseFloorDb ? 0.3 : 0.0008)
        peakDb += (db - peakDb) * (db > peakDb ? 0.5 : 0.004)
        let span = max(peakDb - noiseFloorDb, Self.minRangeDb)
        let level = Float(max(0, min(1, (db - noiseFloorDb) / span)))

        // Envelope follower: jump up to louder input immediately, ease back down
        // fast enough that word/syllable structure stays visible but a single
        // block-sized dip doesn't collapse the meter to a dot.
        let coeff: Float = level > levelEnvelope ? 0.92 : 0.85
        levelEnvelope += (level - levelEnvelope) * coeff
        levelContinuation.yield(levelEnvelope)
    }
}
