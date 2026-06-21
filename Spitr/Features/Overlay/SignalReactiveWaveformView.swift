//
//  SignalReactiveWaveformView.swift
//  Spitr
//
//  A voice-driven cousin of `SignalWaveformView`. Both run the site's perpetual
//  jagged dance (fixed heights × a staggered scaleY .35→1), so the bars are
//  ALWAYS moving — never a static block. The difference is the envelope: the
//  plain style keeps a high floor and scales gently, while this one gates the
//  whole animation by an EXPANDED loudness envelope (low floor, >1 exponent).
//  Soft speech → a small lively line; loud → the full-amplitude dance. The
//  envelope also drives the ripple SPEED (slow when quiet, fast when loud), so
//  both the size and the pace of the movement grow with the voice.
//

import SwiftUI
import Combine

struct SignalReactiveWaveformView: View {
    /// Latest normalized RMS level (0…1) from the audio tap.
    var level: Float

    /// Same two-tone palette as the plain signal style.
    private static let barTop = Color(red: 107 / 255, green: 1.0, blue: 188 / 255)
    private static let barBottom = Color(red: 45 / 255, green: 199 / 255, blue: 140 / 255)

    /// The site's exact jagged `nth-child` heights — keeps the silhouette spiky.
    private static let baseHeights: [Float] = [
        0.24, 0.60, 0.90, 0.45, 0.75, 1.0, 0.55, 0.80, 0.35, 0.65, 0.90, 0.40,
    ]
    private static var barCount: Int { baseHeights.count }

    /// Perpetual ripple, matching the site's 0.06 s delay step over a 1.1 s cycle.
    private static let cycle: Float = 1.1
    private static let phaseStep: Float = 0.06 / 1.1 * 2 * .pi
    /// Floor so quiet still shows a faint, moving line rather than nothing.
    private static let idleFloor: Float = 0.06

    /// Loudness envelope (0…1) scaling the whole dance, and a free-running phase.
    @State private var envelope: Float = 0
    @State private var phase: Float = 0

    private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { ctx, size in
            let n = Self.barCount
            let slot = size.width / CGFloat(n)
            let barWidth = min(slot * 0.42, 5)
            let midY = size.height / 2
            let maxH = size.height
            let omega = 2 * Float.pi / Self.cycle
            let env = max(Self.idleFloor, envelope)

            for i in 0..<n {
                // Continuous scaleY .35→1, staggered per bar — the bars never stop
                // moving; the loudness envelope scales how big the swing reads.
                let osc = 0.5 + 0.5 * sinf(phase * omega - Float(i) * Self.phaseStep)
                let scale = 0.35 + 0.65 * osc
                let frac = Self.baseHeights[i] * scale * env
                let height = max(barWidth, CGFloat(frac) * maxH)

                let x = CGFloat(i) * slot + (slot - barWidth) / 2
                let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)

                // Brightness tracks the live height, so loud bars also glow more.
                let opacity = 0.4 + 0.6 * CGFloat(frac)
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
            // Expanded loudness envelope: dead-zone kills idle hiss, exponent >1
            // widens the quiet↔loud gap. Fast attack, slow release so it pops on
            // speech and eases back.
            let raw = min(max(level, 0), 1)
            let norm = max(0, min(1, (raw - 0.06) / 0.82))
            let target = powf(norm, 1.8)
            let k: Float = target > envelope ? 0.5 : 0.12
            envelope += (target - envelope) * k

            // Loudness also drives the SPEED of the ripple: a quiet line drifts
            // slowly (~0.5×), a loud voice races (~2×) — livelier when shouting.
            let speed = 0.5 + 1.5 * envelope
            phase += (1.0 / 60.0) * speed
        }
    }
}

#Preview {
    SignalReactiveWaveformView(level: 0.8)
        .frame(width: 168, height: 64)
        .padding()
        .background(.black)
}
