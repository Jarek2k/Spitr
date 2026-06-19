//
//  MetalWaveformView.swift
//  Spitr
//
//  GPU-rendered "strands" waveform. Drives the Metal `strands` shader with the
//  live audio level and an animation clock, as a SwiftUI colorEffect.
//

import SwiftUI

struct MetalWaveformView: View {
    /// Latest normalized RMS level (0…1) from the audio tap.
    var level: Float

    /// Smoothed level so the threads breathe instead of jittering per frame.
    @State private var smoothed: Float = 0
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = Float(timeline.date.timeIntervalSince(start))
            Rectangle()
                // A near-invisible fill guarantees the shader runs across the
                // full bounds; the shader itself paints the visible threads.
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
        .onChange(of: level) { _, newValue in
            // Asymmetric smoothing: rise fast, fall slow.
            let factor: Float = newValue > smoothed ? 0.5 : 0.15
            smoothed += (newValue - smoothed) * factor
        }
    }
}

#Preview {
    MetalWaveformView(level: 0.6)
        .frame(width: 220, height: 56)
        .background(.black)
}
