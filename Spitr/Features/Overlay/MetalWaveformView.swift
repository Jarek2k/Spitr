//
//  MetalWaveformView.swift
//  Spitr
//
//  GPU-rendered "strands" waveform. Feeds the current, smoothed audio level to
//  the Metal `strands` shader, which swells a single global amplitude — thin
//  line at rest, threads fanning apart as the voice gets louder.
//

import SwiftUI

struct MetalWaveformView: View {
    /// Latest normalized RMS level (0…1) from the audio tap.
    var level: Float

    /// Smoothed loudness: snaps up to the voice, eases back down, so the swell
    /// tracks speech without jittering on every frame.
    @State private var smoothed: Float = 0
    @State private var start = Date()

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
        .onChange(of: level) { _, newValue in
            let factor: Float = newValue > smoothed ? 0.6 : 0.12
            smoothed += (newValue - smoothed) * factor
        }
    }
}

#Preview {
    MetalWaveformView(level: 0.6)
        .frame(width: 360, height: 100)
        .background(.black)
}
