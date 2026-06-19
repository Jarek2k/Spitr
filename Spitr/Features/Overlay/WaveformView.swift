//
//  WaveformView.swift
//  Spitr
//
//  Audio-reactive scrolling waveform drawn with a SwiftUI Canvas. Kept light:
//  a fixed-size ring buffer of recent input levels rendered as mirrored bars.
//

import SwiftUI

struct WaveformView: View {
    /// Latest normalized RMS level (0…1) from the audio tap.
    var level: Float

    private static let barCount = 28
    @State private var history = [Float](repeating: 0, count: WaveformView.barCount)

    var body: some View {
        // Sample on a steady clock so the bars keep scrolling while a sustained
        // sound holds the level constant — the scroll must not depend on the
        // level *changing*.
        TimelineView(.periodic(from: .now, by: 0.06)) { timeline in
            Canvas { ctx, size in
                guard !history.isEmpty else { return }
                let slot = size.width / CGFloat(history.count)
                let barWidth = slot * 0.62
                let midY = size.height / 2

                for (i, value) in history.enumerated() {
                    let height = max(barWidth, CGFloat(value) * size.height)
                    let x = CGFloat(i) * slot + (slot - barWidth) / 2
                    let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
                    ctx.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(.white.opacity(0.9))
                    )
                }
            }
            .onChange(of: timeline.date) { _, _ in
                history.removeFirst()
                history.append(level)
            }
        }
    }
}

#Preview {
    WaveformView(level: 0.6)
        .frame(width: 220, height: 56)
        .background(.black)
}
