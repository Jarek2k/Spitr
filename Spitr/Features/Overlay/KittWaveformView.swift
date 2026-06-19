//
//  KittWaveformView.swift
//  Spitr
//
//  KITT-style voice box (Knight Rider): three clustered columns of red LED
//  blocks mirrored above and below a centre line. The middle column reacts
//  hard and grows much taller; the two outer columns are always equal to each
//  other and trail the centre (a beat behind), so the whole thing reads as
//  voice-driven, not random. Each lit block fades toward the tip; soft voice →
//  short, loud voice → a tall thick centre with the outers pulling up after.
//

import SwiftUI
import Combine

struct KittWaveformView: View {
    /// Latest normalized RMS level (0…1) from the audio tap.
    var level: Float

    private static let segmentsPerHalf = 6

    /// KITT red.
    private static let red = Color(red: 1.0, green: 0.13, blue: 0.06)

    /// Centre column (fast, full height) and outer columns (slower, shorter).
    @State private var centerLevel: Float = 0
    @State private var outerLevel: Float = 0

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
            // Map loudness with a gentle curve — keeps quiet low and loud high
            // but lets the mid-range come through so there's lots of motion.
            let raw = Double(min(max(level, 0), 1))
            let norm = max(0, min(1, (raw - 0.18) / 0.64))
            let target = Float(pow(norm, 1.35))

            // Centre snaps and decays fast (lots happening); outers trail it.
            centerLevel += (target - centerLevel) * (target > centerLevel ? 0.92 : 0.82)
            outerLevel  += (target - outerLevel)  * (target > outerLevel ? 0.62 : 0.55)
        }
    }

    private func drawBars(in ctx: GraphicsContext, size: CGSize) {
        let n = 3
        let halfSegs = Self.segmentsPerHalf

        let barWidth = size.width * 0.19
        let gapX = size.width * 0.055
        let total = CGFloat(n) * barWidth + CGFloat(n - 1) * gapX
        let startX = (size.width - total) / 2

        let midY = size.height / 2
        let segGap: CGFloat = 2
        let usableHalf = size.height / 2 - 2
        let segH = (usableHalf - CGFloat(halfSegs - 1) * segGap) / CGFloat(halfSegs)
        guard segH > 0 else { return }

        for i in 0..<n {
            let isCenter = (i == 1)
            // Centre uses its full level; outers are shorter and share one value
            // (so left and right are always identical) and lag behind.
            let frac = isCenter ? Double(centerLevel) : Double(outerLevel) * 0.5
            let idle = isCenter ? 0.10 : 0.05
            let h = max(idle, frac)

            let lit = Int((h * Double(halfSegs)).rounded())
            guard lit > 0 else { continue }

            let x = startX + CGFloat(i) * (barWidth + gapX)
            for s in 0..<lit {
                let bright = max(0.12, 1.0 - 0.8 * Double(s) / Double(halfSegs - 1))
                let dy = CGFloat(s) * (segH + segGap)
                let up = CGRect(x: x, y: midY - segGap / 2 - segH - dy, width: barWidth, height: segH)
                let down = CGRect(x: x, y: midY + segGap / 2 + dy, width: barWidth, height: segH)
                let color = Self.red.opacity(bright)
                ctx.fill(Path(roundedRect: up, cornerRadius: 2), with: .color(color))
                ctx.fill(Path(roundedRect: down, cornerRadius: 2), with: .color(color))
            }
        }
    }
}

#Preview {
    KittWaveformView(level: 0.7)
        .frame(width: 220, height: 116)
        .background(.black)
}
