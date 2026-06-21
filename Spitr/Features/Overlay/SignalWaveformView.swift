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

    /// Per-bar vertical gradient: bright mint at the top fading to a deeper green
    /// at the base, matching the two-tone bars in the site animation.
    private static let barTop = Color(red: 107 / 255, green: 1.0, blue: 188 / 255)
    private static let barBottom = Color(red: 45 / 255, green: 199 / 255, blue: 140 / 255)

    /// Fixed per-bar base heights — the site's exact `nth-child` values
    /// (24/60/90/45/75/100/…%). Deliberately jagged so neighbours differ a lot
    /// and the row reads as a spiky signal, not a smooth travelling curve.
    private static let baseHeights: [Float] = [
        0.24, 0.60, 0.90, 0.45, 0.75, 1.0, 0.55, 0.80, 0.35, 0.65, 0.90, 0.40,
    ]
    private static var barCount: Int { baseHeights.count }

    /// Per-bar phase stagger, matching the site's 0.06 s animation-delay step
    /// over its 1.1 s cycle — a gentle ripple, while the fixed heights keep the
    /// silhouette jagged.
    private static let cycle: Float = 1.1
    private static let phaseStep: Float = 0.06 / 1.1 * 2 * .pi

    /// Smoothed loudness and a free-running phase that drives the per-bar pulse.
    @State private var amplitude: Float = 0
    @State private var phase: Float = 0

    private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { ctx, size in
            let n = Self.barCount
            let slot = size.width / CGFloat(n)
            // Thin bars with airy gaps, like the site (≈5 px bars).
            let barWidth = min(slot * 0.42, 5)
            let midY = size.height / 2
            let maxH = size.height
            let omega = 2 * Float.pi / Self.cycle

            for i in 0..<n {
                // Each bar scales between 0.35× and 1× of its OWN fixed height,
                // on a staggered phase — exactly the site's scaleY .35→1 keyframe.
                let osc = 0.5 + 0.5 * sinf(phase * omega - Float(i) * Self.phaseStep)
                let scale = 0.35 + 0.65 * osc
                // Idle floor + audio-driven gain: quiet → low shimmer, loud → full.
                let gain = 0.12 + 0.88 * amplitude
                let frac = CGFloat(Self.baseHeights[i] * scale * gain)
                let height = max(barWidth, frac * maxH)

                let x = CGFloat(i) * slot + (slot - barWidth) / 2
                let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)

                // Taller bars glow brighter than short ones (height → opacity),
                // with a faint odd/even offset so neighbours stay distinct.
                let bright = 0.45 + 0.55 * CGFloat(scale)
                let opacity = bright * (i % 2 == 0 ? 0.82 : 1.0)
                let gradient = Gradient(colors: [
                    Self.barTop.opacity(opacity),
                    Self.barBottom.opacity(opacity),
                ])
                ctx.fill(
                    Path(roundedRect: rect, cornerRadius: barWidth / 2),
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: rect.midX, y: rect.minY),
                        endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                    )
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
