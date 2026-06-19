//
//  KittWaveformView.swift
//  Spitr
//
//  KITT-style voice box (Knight Rider): three clustered columns of red LED
//  segments mirrored above and below a centre line. The middle column reaches
//  higher than the two outer ones, and each lit segment fades toward the tip
//  (bright at the centre → dark at the ends). Height tracks loudness — far apart
//  when loud, short when quiet — with a small per-bar jiggle and a red glow.
//

import SwiftUI
import Combine

struct KittWaveformView: View {
    /// Latest normalized RMS level (0…1) from the audio tap.
    var level: Float

    private static let barCount = 3
    private static let segmentsPerHalf = 7

    /// KITT red.
    private static let red = Color(red: 1.0, green: 0.13, blue: 0.06)

    @State private var smoothed: Float = 0
    @State private var clock: Double = 0

    private let ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { ctx, size in
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 4))
                drawBars(in: layer, size: size)
            }
            drawBars(in: ctx, size: size)
        }
        .onReceive(ticker) { _ in
            clock += 1.0 / 30.0
            let target = min(max(level, 0), 1)
            let factor: Float = target > smoothed ? 0.6 : 0.25
            smoothed += (target - smoothed) * factor
        }
    }

    private func drawBars(in ctx: GraphicsContext, size: CGSize) {
        let n = Self.barCount
        let halfSegs = Self.segmentsPerHalf

        // Cluster the three columns near the centre with thick bars, small gaps.
        let barWidth = size.width * 0.19
        let gapX = size.width * 0.05
        let total = CGFloat(n) * barWidth + CGFloat(n - 1) * gapX
        let startX = (size.width - total) / 2

        let midY = size.height / 2
        let segGap: CGFloat = 1.5
        let usableHalf = size.height / 2 - 2
        let segH = (usableHalf - CGFloat(halfSegs - 1) * segGap) / CGFloat(halfSegs)
        guard segH > 0 else { return }

        for i in 0..<n {
            // Centre column tallest, outer columns clearly shorter.
            let centerDist = abs(CGFloat(i) - CGFloat(n - 1) / 2) / (CGFloat(n - 1) / 2)
            let env = 1.0 - 0.6 * Double(centerDist)

            let jiggle = 0.82 + 0.18 * sin(clock * 6.5 + Double(i) * 1.7)
            let idle = 0.12 * env
            let h = max(idle, Double(smoothed) * env * jiggle)

            let lit = Int((h * Double(halfSegs)).rounded())
            guard lit > 0 else { continue }

            let x = startX + CGFloat(i) * (barWidth + gapX)
            for s in 0..<lit {
                // Fade toward the tip: bright near the centre line, dim at the end.
                let bright = max(0.12, 1.0 - 0.85 * Double(s) / Double(halfSegs - 1))
                let dy = CGFloat(s) * (segH + segGap)
                let up = CGRect(x: x, y: midY - segGap / 2 - segH - dy, width: barWidth, height: segH)
                let down = CGRect(x: x, y: midY + segGap / 2 + dy, width: barWidth, height: segH)
                let color = Self.red.opacity(bright)
                ctx.fill(Path(roundedRect: up, cornerRadius: 1.5), with: .color(color))
                ctx.fill(Path(roundedRect: down, cornerRadius: 1.5), with: .color(color))
            }
        }
    }
}

#Preview {
    KittWaveformView(level: 0.7)
        .frame(width: 220, height: 116)
        .background(.black)
}
