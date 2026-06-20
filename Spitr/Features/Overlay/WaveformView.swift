//
//  WaveformView.swift
//  Spitr
//
//  Audio-reactive scrolling waveform drawn with a SwiftUI Canvas. A fixed-size
//  ring buffer of recent input levels rendered as mirrored bars, sampled on a
//  steady timer so it scrolls like an audio track regardless of whether the
//  level is changing.
//

import SwiftUI
import Combine

struct WaveformView: View {
    /// Latest normalized RMS level (0…1) from the audio tap.
    var level: Float

    /// Bar colour — yellow in command mode keeps that mode visually distinct.
    var tint: Color = .white.opacity(0.9)

    private static let barCount = 40
    @State private var history = [Float](repeating: 0, count: WaveformView.barCount)

    /// Steady sampling clock — drives the scroll independent of level changes.
    private let ticker = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { ctx, size in
            guard !history.isEmpty else { return }
            let slot = size.width / CGFloat(history.count)
            let barWidth = slot * 0.55
            let midY = size.height / 2

            for (i, value) in history.enumerated() {
                let height = max(barWidth, CGFloat(value) * size.height)
                let x = CGFloat(i) * slot + (slot - barWidth) / 2
                let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
                ctx.fill(
                    Path(roundedRect: rect, cornerRadius: barWidth / 2),
                    with: .color(tint)
                )
            }
        }
        .onReceive(ticker) { _ in
            history.removeFirst()
            history.append(level)
        }
    }
}

#Preview {
    WaveformView(level: 0.6)
        .frame(width: 220, height: 56)
        .background(.black)
}
