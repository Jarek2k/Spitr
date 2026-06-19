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

    private let engine = AVAudioEngine()

    /// UID of the microphone to capture from. Empty/nil → system default input.
    /// Set by RecordingController from Settings; applied on the next start().
    var preferredDeviceUID: String?

    private let lock = NSLock()
    private var samples: [Float] = []

    /// Envelope follower for the level meter: fast attack, slow release, so the
    /// gaps between syllables don't collapse the waveform to a dot.
    private var levelEnvelope: Float = 0

    /// Adaptive loudness range (dBFS), tracked across recordings so the meter
    /// fits any microphone: a slow noise floor and a recent-peak ceiling.
    private var noiseFloorDb: Double = AudioCaptureService.initialFloorDb
    private var peakDb: Double = AudioCaptureService.initialPeakDb

    private var converter: AVAudioConverter?
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

        lock.lock()
        samples.removeAll(keepingCapacity: true)
        lock.unlock()
        levelEnvelope = 0

        let input = engine.inputNode
        applyPreferredDevice(to: input)
        let inputFormat = input.outputFormat(forBus: 0)

        guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: Self.targetSampleRate,
                                         channels: 1,
                                         interleaved: false) else {
            throw AudioCaptureError.formatUnavailable
        }
        self.targetFormat = target
        self.converter = AVAudioConverter(from: inputFormat, to: target)

        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
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

    private func handleTap(_ input: AVAudioPCMBuffer) {
        guard let converter, let targetFormat else { return }

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
        lock.unlock()

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
        let coeff: Float = level > levelEnvelope ? 0.7 : 0.35
        levelEnvelope += (level - levelEnvelope) * coeff
        levelContinuation.yield(levelEnvelope)
    }
}
