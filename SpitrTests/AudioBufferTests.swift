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
}
