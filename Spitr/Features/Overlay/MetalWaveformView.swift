//
//  MetalWaveformView.swift
//  Spitr
//
//  GPU-rendered "strands" waveform. Keeps a short ring buffer of recent audio
//  levels (like the bar waveform) and feeds it to the Metal `strands` shader,
//  which modulates the threads per position — so the motion tracks the voice.
//

import SwiftUI

struct MetalWaveformView: View {
    /// Latest normalized RMS level (0…1) from the audio tap.
    var level: Float

    /// History length — must match `kCount` in Waveform.metal.
    static let count = 48
    @State private var history = [Float](repeating: 0, count: MetalWaveformView.count)
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
                            .floatArray(history)
                        )
                    )
                }
        }
        .onChange(of: level) { _, newValue in
            // Scroll the buffer left, newest sample on the right.
            history.removeFirst()
            history.append(min(max(newValue, 0), 1))
        }
    }
}

#Preview {
    MetalWaveformView(level: 0.6)
        .frame(width: 360, height: 100)
        .background(.black)
}
