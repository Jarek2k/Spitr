//
//  MetalWaveformView.swift
//  Spitr
//
//  GPU-rendered "strands" waveform. Smooths the audio level *per animation
//  frame* (time-constant based) rather than per audio block, so the swell
//  glides instead of stepping, then feeds it to the Metal `strands` shader.
//

import SwiftUI

struct MetalWaveformView: View {
    /// Latest normalized RMS level (0…1) from the audio tap.
    var level: Float

    @State private var smoothed: Float = 0
    @State private var target: Float = 0
    @State private var start = Date()
    @State private var lastTick = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let t = Float(now.timeIntervalSince(start))
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
                .onChange(of: now) { _, newNow in
                    // Exponential smoothing toward the latest level, advanced
                    // every frame. Asymmetric: snaps up to the voice, eases down.
                    let dt = Float(max(0, min(0.1, newNow.timeIntervalSince(lastTick))))
                    lastTick = newNow
                    let tau: Float = target > smoothed ? 0.06 : 0.22
                    smoothed += (target - smoothed) * (1 - exp(-dt / tau))
                }
        }
        .onChange(of: level) { _, newValue in
            target = min(max(newValue, 0), 1)
        }
    }
}

#Preview {
    MetalWaveformView(level: 0.6)
        .frame(width: 360, height: 100)
        .background(.black)
}
