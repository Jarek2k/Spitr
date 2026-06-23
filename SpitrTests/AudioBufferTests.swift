//
//  AudioBufferTests.swift
//  SpitrTests
//
//  Guards the silence gate that stops Whisper from hallucinating a sentence out
//  of a near-silent capture (its own no-speech detection is unimplemented). The
//  threshold must drop true silence/noise-floor clips while keeping even a quiet
//  spoken word.
//

import Testing
import Foundation
@testable import Spitr

struct AudioBufferTests {

    /// A constant-amplitude tone at the given peak — stands in for "loudest sample
    /// reaches this level", which is all the gate looks at.
    private func tone(peak: Float, count: Int = 16_000) -> AudioBuffer {
        AudioBuffer(samples: Array(repeating: peak, count: count), sampleRate: 16_000)
    }

    @Test func pureSilenceIsSilent() {
        let buffer = AudioBuffer(samples: Array(repeating: 0, count: 16_000), sampleRate: 16_000)
        #expect(buffer.peakDBFS == -.infinity)
        #expect(buffer.isLikelySilent)
    }

    @Test func emptyBufferIsSilent() {
        let buffer = AudioBuffer(samples: [], sampleRate: 16_000)
        #expect(buffer.isLikelySilent)
    }

    @Test func noiseFloorIsSilent() {
        // ~ -54 dBFS: mic self-noise / a quiet room — below the -40 dB gate.
        #expect(tone(peak: 0.002).isLikelySilent)
    }

    @Test func quietSpokenWordIsNotSilent() {
        // ~ -34 dBFS: a softly spoken word still peaks above the gate.
        #expect(!tone(peak: 0.02).isLikelySilent)
    }

    @Test func normalSpeechIsNotSilent() {
        // ~ -6 dBFS: ordinary dictation level.
        #expect(!tone(peak: 0.5).isLikelySilent)
    }

    @Test func peakIgnoresSurroundingSilence() {
        // One loud sample amid silence: peak-based detection still sees the word,
        // where an RMS average would wrongly read the clip as silent.
        var samples = Array<Float>(repeating: 0, count: 16_000)
        samples[8_000] = 0.3
        let buffer = AudioBuffer(samples: samples, sampleRate: 16_000)
        #expect(!buffer.isLikelySilent)
    }

    @Test func trimmingLeadingDropsTheChimeWindow() {
        // 1 s buffer at 16 kHz; drop the first 0.2 s → 0.8 s / 12 800 samples left.
        let buffer = tone(peak: 0.5, count: 16_000)
        let trimmed = buffer.trimmingLeading(0.2)
        #expect(trimmed.samples.count == 12_800)
        #expect(trimmed.sampleRate == 16_000)
    }

    @Test func trimmingLeadingClampsAnOverShortBuffer() {
        // Trimming more than the buffer holds yields empty, not a crash.
        let buffer = tone(peak: 0.5, count: 1_000)
        let trimmed = buffer.trimmingLeading(1.0)
        #expect(trimmed.samples.isEmpty)
        #expect(trimmed.isLikelySilent)
    }

    @Test func chimeBleedIsGatedAfterTrimming() {
        // A capture that is just the chime bleed (loud start) followed by silence
        // reads as speech on the full buffer, but as silence once the chime window
        // is trimmed — which is the order finishRecording uses.
        var samples = Array<Float>(repeating: 0, count: 16_000)
        for i in 0..<2_400 { samples[i] = 0.3 }   // ~0.15 s of chime at the start
        let buffer = AudioBuffer(samples: samples, sampleRate: 16_000)
        #expect(!buffer.isLikelySilent)                       // chime makes it look loud
        #expect(buffer.trimmingLeading(0.21).isLikelySilent)  // gone after trim
    }
}
