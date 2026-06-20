//
//  FeedbackSoundService.swift
//  Spitr
//
//  Plays a short "ready" chime the instant the mic starts capturing, so the
//  user knows when to begin speaking and doesn't clip the first word.
//
//  Self-contained: the tone is synthesized in memory (no bundled asset) and
//  preloaded once, so playback at key-down has no decode/load latency.
//

import Foundation
import AVFoundation

final class FeedbackSoundService {
    private let player: AVAudioPlayer?

    init() {
        player = Self.makeChime().flatMap { try? AVAudioPlayer(data: $0) }
        player?.volume = 0.45
        player?.prepareToPlay()
    }

    /// Plays the ready chime from the start. Safe to call repeatedly and from the
    /// main thread; a no-op if synthesis failed.
    func playReady() {
        guard let player else { return }
        player.currentTime = 0
        player.play()
    }

    // MARK: - Tone synthesis

    /// A warm, unobtrusive sine blip with a raised-cosine envelope (so it fades
    /// in/out without clicks), rendered to a 16-bit mono WAV in memory.
    private static func makeChime() -> Data? {
        let sampleRate = 44_100.0
        let duration = 0.11          // short — a cue, not a notification
        let frequency = 830.0        // ~G#5: present but not shrill
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
