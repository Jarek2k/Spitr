//
//  FeedbackSoundService.swift
//  Spitr
//
//  Plays two short cues: a "ready" chime the instant the mic starts capturing
//  (so the user knows when to begin speaking and doesn't clip the first word),
//  and a "done" chime once the transcript has been inserted (so the wait during
//  transcription has an audible end — useful with slower engines).
//
//  Self-contained: the tones are synthesized in memory (no bundled asset) and
//  preloaded once, so playback has no decode/load latency.
//

import Foundation
import AVFoundation
import os

private let log = Logger(subsystem: "com.jarek.Spitr", category: "feedback")

final class FeedbackSoundService {
    private let readyPlayer: AVAudioPlayer?
    private let donePlayer: AVAudioPlayer?

    init() {
        readyPlayer = Self.makeBlip(frequency: 880).flatMap { try? AVAudioPlayer(data: $0) }
        readyPlayer?.volume = 0.9
        readyPlayer?.prepareToPlay()

        // Done: a soft two-note descending blip, distinct from the single rising
        // "ready" cue so the two are never confused.
        donePlayer = Self.makeDone().flatMap { try? AVAudioPlayer(data: $0) }
        donePlayer?.volume = 0.85
        donePlayer?.prepareToPlay()

        if readyPlayer == nil || donePlayer == nil {
            log.error("feedback players failed to init (ready=\(self.readyPlayer != nil) done=\(self.donePlayer != nil))")
        }
    }

    /// Plays the ready chime from the start. Safe to call repeatedly and from the
    /// main thread; a no-op if synthesis failed.
    func playReady() {
        guard let readyPlayer else { log.error("ready chime: no player"); return }
        readyPlayer.currentTime = 0
        if !readyPlayer.play() { log.error("ready chime play() returned false") }
    }

    /// Plays the done chime — the audible end of a dictation, once text is in.
    func playDone() {
        guard let donePlayer else { return }
        donePlayer.currentTime = 0
        donePlayer.play()
    }

    // MARK: - Tone synthesis

    /// A warm, unobtrusive sine blip with a raised-cosine envelope (so it fades
    /// in/out without clicks), rendered to a 16-bit mono WAV in memory.
    private static func makeBlip(frequency: Double) -> Data? {
        let sampleRate = 44_100.0
        let duration = 0.15          // short — a cue, not a notification
        let fade = 0.012             // 12 ms in/out
        let amplitude = 0.6

        let frameCount = Int(sampleRate * duration)
        guard frameCount > 0 else { return nil }

        var pcm = [Int16]()
        pcm.reserveCapacity(frameCount)
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            var env = 1.0
            if t < fade { env = 0.5 * (1 - cos(.pi * t / fade)) }
            let tail = duration - t
            if tail < fade { env = min(env, 0.5 * (1 - cos(.pi * tail / fade))) }
            let value = sin(2 * .pi * frequency * t) * amplitude * env
            pcm.append(Int16(max(-1, min(1, value)) * Double(Int16.max)))
        }
        return wav(pcm: pcm, sampleRate: Int(sampleRate))
    }

    /// Two short descending notes (G#5 → C#5) — reads as a gentle "finished"
    /// confirmation, clearly different from the single-note ready cue.
    private static func makeDone() -> Data? {
        let sampleRate = 44_100.0
        let noteDuration = 0.085
        let fade = 0.01
        let amplitude = 0.55
        let frequencies = [830.0, 554.0]   // ~G#5, ~C#5

        var pcm = [Int16]()
        for frequency in frequencies {
            let frameCount = Int(sampleRate * noteDuration)
            guard frameCount > 0 else { return nil }
            for i in 0..<frameCount {
                let t = Double(i) / sampleRate
                var env = 1.0
                if t < fade { env = 0.5 * (1 - cos(.pi * t / fade)) }
                let tail = noteDuration - t
                if tail < fade { env = min(env, 0.5 * (1 - cos(.pi * tail / fade))) }
                let value = sin(2 * .pi * frequency * t) * amplitude * env
                pcm.append(Int16(max(-1, min(1, value)) * Double(Int16.max)))
            }
        }
        return wav(pcm: pcm, sampleRate: Int(sampleRate))
    }

    /// Wraps raw 16-bit mono PCM in a minimal canonical WAV container.
    private static func wav(pcm: [Int16], sampleRate: Int) -> Data {
        var data = Data()
        let byteRate = sampleRate * 2
        let dataSize = pcm.count * 2

        func ascii(_ s: String) { data.append(contentsOf: s.utf8) }
        func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }

        ascii("RIFF"); u32(UInt32(36 + dataSize)); ascii("WAVE")
        ascii("fmt "); u32(16); u16(1); u16(1)          // PCM, 1 channel
        u32(UInt32(sampleRate)); u32(UInt32(byteRate)); u16(2); u16(16)
        ascii("data"); u32(UInt32(dataSize))
        for sample in pcm { u16(UInt16(bitPattern: sample)) }
        return data
    }
}
