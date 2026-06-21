//
//  SignalWaveformView.swift
//  Spitr
//
//  The "signal" waveform from the product site: a fixed row of rounded, spring-
//  green bars that grow from a shared centre line — louder voice, taller bars.
//  Unlike the scrolling `WaveformView`, the bars stay in place and breathe; each
//  bar carries its own phase so the row ripples instead of pulsing as one block.
//  Drawn with a SwiftUI Canvas — cheap enough for the always-on overlay.
//

import SwiftUI
import Combine

struct SignalWaveformView: View {
    /// Latest normalized RMS level (0…1) from the audio tap.
    var level: Float

    var tint: Color = SpitrTheme.brand

    /// Fixed per-bar base heights — deliberately jagged (like the site's
    /// `nth-child` heights 24/60/90/45/…%), so neighbours differ a lot and the
    /// row reads as a spiky signal, not a smooth travelling curve.
    private static let baseHeights: [Float] = [
        0.30, 0.62, 0.92, 0.45, 0.78, 1.0, 0.52, 0.85, 0.38, 0.70, 0.95, 0.48, 0.66, 0.34,
    ]
    /// Scattered phase offsets (not linear in i) so the bars don't pulse in a
    /// wave — each rises and falls on its own beat, like staggered CSS delays.
    private static let phaseOffsets: [Float] = [
        0.0, 2.1, 4.3, 1.2, 3.6, 5.4, 0.7, 2.8, 4.9, 1.6, 3.1, 5.0, 2.4, 0.4,
    ]
    private static var barCount: Int { baseHeights.count }

    /// Smoothed loudness and a free-running phase that drives the per-bar pulse.
    @State private var amplitude: Float = 0
    @State private var phase: Float = 0

    private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { ctx, size in
            let n = Self.barCount
            let slot = size.width / CGFloat(n)
            let barWidth = min(slot * 0.5, 6)
            let midY = size.height / 2
            let maxH = size.height

            for i in 0..<n {
                // Each bar scales between 0.4× and 1× of its OWN fixed height, on
                // its own phase — the jagged base shape stays; only the height
                // breathes. (Mirrors the site's scaleY .35→1 keyframe.)
                let osc = 0.5 + 0.5 * sinf(phase * 4.6 + Self.phaseOffsets[i])
                let scale = 0.4 + 0.6 * osc
                // Idle floor + audio-driven gain: quiet → low shimmer, loud → full.
                let gain = 0.12 + 0.88 * amplitude
                let frac = CGFloat(Self.baseHeights[i] * scale * gain)
                let height = max(barWidth, frac * maxH)

                let x = CGFloat(i) * slot + (slot - barWidth) / 2
                let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
                // Alternate bars sit back a touch, like the site's waveform.
                let opacity = i % 2 == 0 ? 0.55 : 0.95
                ctx.fill(
                    Path(roundedRect: rect, cornerRadius: barWidth / 2),
                    with: .color(tint.opacity(opacity))
                )
            }
        }
        .onReceive(ticker) { _ in
            phase += 1.0 / 60.0
            // Map loudness with a gentle curve, then smooth — fast attack so the
            // bars jump on speech, slower release so they settle naturally.
            let raw = min(max(level, 0), 1)
            let norm = max(0, min(1, (raw - 0.12) / 0.7))
            let target = powf(norm, 1.3)
            let k: Float = target > amplitude ? 0.5 : 0.12
            amplitude += (target - amplitude) * k
        }
    }
}

#Preview {
    SignalWaveformView(level: 0.6)
        .frame(width: 220, height: 56)
        .padding()
        .background(.black)
}
