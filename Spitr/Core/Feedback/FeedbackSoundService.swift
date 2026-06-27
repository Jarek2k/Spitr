//
//  FeedbackSoundService.swift
//  Spitr
//
//  Plays two short cues: a "ready" chime the instant the mic starts capturing
//  (so the user knows when to begin speaking and doesn't clip the first word),
//  and a "done" chime once the transcript has been inserted (so the wait during
//  transcription has an audible end — useful with slower engines).
//
//  The ready cue has a few selectable styles (single blip, double beep, rising
//  push-to-talk "go" tone). Self-contained: all tones are synthesized in memory
//  (no bundled asset) and preloaded once, so playback has no decode/load latency.
//

import Foundation
import AVFoundation

private let log = DiagLog(category: "feedback")

/// One tone in a cue: a frequency held for a duration. The synthesizer inserts a
/// short silent gap between consecutive notes.
private struct Note {
    let frequency: Double
    let duration: TimeInterval
}

/// The exchangeable decision "what the ready cue sounds like". Adding a style is
/// one case here plus its note sequence — nothing else needs to change.
enum ReadyChimeStyle: String, CaseIterable, Identifiable {
    /// A single warm blip (880 Hz). Minimal.
    case single
    /// Two equal blips — the familiar "beep-beep" of a voice-message / recorder
    /// start cue. The default.
    case double
    /// Two ascending notes — the push-to-talk "talk-permit" cue that reads as
    /// "go ahead, speak".
    case rising

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .single: return String(localized: "Einzelton")
        case .double: return String(localized: "Doppelton")
        case .rising: return String(localized: "Aufsteigend (Funk)")
        }
    }

    /// The notes that make up the cue, in order.
    fileprivate var notes: [Note] {
        switch self {
        case .single: return [Note(frequency: 880, duration: 0.15)]
        case .double: return [Note(frequency: 880, duration: 0.085),
                              Note(frequency: 880, duration: 0.085)]
        case .rising: return [Note(frequency: 660, duration: 0.085),
                              Note(frequency: 988, duration: 0.10)]
        }
    }
}

final class FeedbackSoundService {
    /// Silent gap inserted between consecutive notes of a multi-note cue. Short,
    /// so the two beeps read as one snappy "beep-beep" rather than two separate
    /// tones.
    private static let interNoteGap: TimeInterval = 0.03

    /// Total length of a ready cue (all notes + the gaps between them). The
    /// recorder trims exactly this window (plus slack) of speaker-bleed off the
    /// start of a capture — single source of truth with the synthesis below.
    static func readyChimeDuration(for style: ReadyChimeStyle) -> TimeInterval {
        let notes = style.notes
        let tones = notes.reduce(0) { $0 + $1.duration }
        let gaps = Double(max(0, notes.count - 1)) * interNoteGap
        return tones + gaps
    }

    /// One preloaded player per ready style, so switching/auditioning is instant.
    private let readyPlayers: [ReadyChimeStyle: AVAudioPlayer]
    private let donePlayer: AVAudioPlayer?

    init() {
        var players: [ReadyChimeStyle: AVAudioPlayer] = [:]
        for style in ReadyChimeStyle.allCases {
            guard let data = Self.makeReady(style: style),
                  let player = try? AVAudioPlayer(data: data) else { continue }
            player.volume = 0.9
            player.prepareToPlay()
            players[style] = player
        }
        readyPlayers = players

        // Done: a soft two-note descending blip, distinct from every ready cue so
        // start and end are never confused.
        donePlayer = Self.makeDone().flatMap { try? AVAudioPlayer(data: $0) }
        donePlayer?.volume = 0.85
        donePlayer?.prepareToPlay()

        if players.count != ReadyChimeStyle.allCases.count || donePlayer == nil {
            log.error("feedback players failed to init (ready=\(players.count)/\(ReadyChimeStyle.allCases.count) done=\(self.donePlayer != nil))")
        }
    }

    /// Plays the given ready cue from the start. Safe to call repeatedly and from
    /// the main thread; a no-op if synthesis failed.
    func playReady(_ style: ReadyChimeStyle) {
        guard let player = readyPlayers[style] else {
            log.error("ready chime: no player for \(style.rawValue)")
            return
        }
        player.currentTime = 0
        if !player.play() { log.error("ready chime play() returned false") }
    }

    /// Plays the done chime — the audible end of a dictation, once text is in.
    func playDone() {
        guard let donePlayer else { return }
        donePlayer.currentTime = 0
        donePlayer.play()
    }

    // MARK: - Tone synthesis

    /// Renders a ready cue (one or more sine notes with raised-cosine envelopes so
    /// they fade in/out without clicks, separated by short silent gaps) to a
    /// 16-bit mono WAV in memory.
    private static func makeReady(style: ReadyChimeStyle) -> Data? {
        let sampleRate = 44_100.0
        let fade = 0.012             // 12 ms in/out
        let amplitude = 0.6
        let gapFrames = Int(sampleRate * interNoteGap)

        var pcm = [Int16]()
        for (index, note) in style.notes.enumerated() {
            if index > 0 { pcm.append(contentsOf: repeatElement(0, count: gapFrames)) }
            let frameCount = Int(sampleRate * note.duration)
            guard frameCount > 0 else { continue }
            for i in 0..<frameCount {
                let t = Double(i) / sampleRate
                var env = 1.0
                if t < fade { env = 0.5 * (1 - cos(.pi * t / fade)) }
                let tail = note.duration - t
                if tail < fade { env = min(env, 0.5 * (1 - cos(.pi * tail / fade))) }
                let value = sin(2 * .pi * note.frequency * t) * amplitude * env
                pcm.append(Int16(max(-1, min(1, value)) * Double(Int16.max)))
            }
        }
        guard !pcm.isEmpty else { return nil }
        return wav(pcm: pcm, sampleRate: Int(sampleRate))
    }

    /// Two short descending notes (G#5 → C#5) — reads as a gentle "finished"
    /// confirmation, clearly different from the ready cues.
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
