//
//  KittWaveformView.swift
//  Spitr
//
//  KITT-style voice box (Knight Rider): a row of red, segmented LED bars
//  mirrored above and below a centre line, tallest in the middle and tapering
//  to the edges. Bar height tracks loudness; each bar jiggles a little on its
//  own so it reads as the classic oscillating modulator, with a soft red glow.
//

import SwiftUI
import Combine

struct KittWaveformView: View {
    /// Latest normalized RMS level (0…1) from the audio tap.
    var level: Float

    private static let barCount = 3
    private static let segmentsPerHalf = 8

    /// KITT red.
    private static let red = Color(red: 1.0, green: 0.12, blue: 0.05)

    @State private var smoothed: Float = 0
    @State private var clock: Double = 0

    private let ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { ctx, size in
            // Soft glow underlay, then crisp segments on top.
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 3))
                drawBars(in: layer, size: size, color: Self.red.opacity(0.9))
            }
            drawBars(in: ctx, size: size, color: Self.red)
        }
        .onReceive(ticker) { _ in
            clock += 1.0 / 30.0
            let target = min(max(level, 0), 1)
            // Fast attack, gentle release — bouncy like the original.
            let factor: Float = target > smoothed ? 0.6 : 0.25
            smoothed += (target - smoothed) * factor
        }
    }

    private func drawBars(in ctx: GraphicsContext, size: CGSize, color: Color) {
        let n = Self.barCount
        let halfSegs = Self.segmentsPerHalf
        let slot = size.width / CGFloat(n)
        let barWidth = slot * 0.55
        let midY = size.height / 2
        let segGap: CGFloat = 2

        let usableHalf = size.height / 2 - 3
        let segH = (usableHalf - CGFloat(halfSegs - 1) * segGap) / CGFloat(halfSegs)
        guard segH > 0 else { return }

        for i in 0..<n {
            let xnorm = (CGFloat(i) + 0.5) / CGFloat(n)
            let centerDist = abs(xnorm - 0.5) * 2          // 0 centre … 1 edge
            let env = 1.0 - 0.28 * Double(centerDist)      // centre tallest, outers ~0.8

            // Per-bar jiggle so the bars don't move in lockstep.
            let jiggle = 0.78 + 0.22 * sin(clock * 6.5 + Double(i) * 1.3)
            // Idle floor keeps a little life in the centre when quiet.
            let idle = 0.10 * env
            let h = max(idle, Double(smoothed) * env * jiggle)

            let lit = Int((h * Double(halfSegs)).rounded())
            guard lit > 0 else { continue }

            let x = CGFloat(i) * slot + (slot - barWidth) / 2
            for s in 0..<lit {
                let dy = CGFloat(s) * (segH + segGap)
                let up = CGRect(x: x, y: midY - segGap / 2 - segH - dy, width: barWidth, height: segH)
                let down = CGRect(x: x, y: midY + segGap / 2 + dy, width: barWidth, height: segH)
                let r1 = Path(roundedRect: up, cornerRadius: 1.5)
                let r2 = Path(roundedRect: down, cornerRadius: 1.5)
                ctx.fill(r1, with: .color(color))
                ctx.fill(r2, with: .color(color))
            }
        }
    }
}

#Preview {
    KittWaveformView(level: 0.7)
        .frame(width: 240, height: 64)
        .background(.black)
}
