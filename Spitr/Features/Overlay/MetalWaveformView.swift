//
//  MetalWaveformView.swift
//  Spitr
//
//  GPU-rendered "strands" waveform. Smooths the audio level *per animation
//  frame* (time-constant based) rather than per audio block, so the swell
//  glides instead of stepping, then feeds it to the Metal `strands` shader.
//

import SwiftUI
import Combine

struct MetalWaveformView: View {
    /// Latest normalized RMS level (0…1) from the audio tap.
    var level: Float

    @State private var smoothed: Float = 0
    @State private var start = Date()

    /// Smoothing/redraw clock. Mutating state here (not inside onChange-of-date)
    /// avoids SwiftUI's "update multiple times per frame" warning.
    private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = Float(timeline.date.timeIntervalSince(start))
            Rectangle()
                // Near-invisible fill guarantees the shader runs across the full
                // bounds; the shader paints (and clips to) the visible threads.
                .fill(Color.white.opacity(0.001))
                .visualEffect { content, proxy in
                    content.colorEffect(
                        ShaderLibrary.strands(
                            .float2(proxy.size.width, proxy.size.height),
                            .float(t),
                            .float(smoothed)
                        )
                    )
                }
        }
        .onReceive(ticker) { _ in
            // Exponential smoothing toward the latest level. Asymmetric: snaps up
            // to the voice, eases back down.
            // Light, fast smoothing only — the audio envelope already does the
            // temporal shaping, so keep this responsive (not sluggish).
            let target = min(max(level, 0), 1)
            let dt: Float = 1.0 / 60.0
            let tau: Float = target > smoothed ? 0.04 : 0.08
            smoothed += (target - smoothed) * (1 - exp(-dt / tau))
        }
    }
}

#Preview {
    MetalWaveformView(level: 0.6)
        .frame(width: 360, height: 100)
        .background(.black)
}
