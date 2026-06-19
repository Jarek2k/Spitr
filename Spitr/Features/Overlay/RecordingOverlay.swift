//
//  RecordingOverlay.swift
//  Spitr
//
//  The floating capsule shown only while recording: a mic glyph plus the
//  audio-reactive waveform. Rendered into a non-activating panel so it never
//  steals focus from the window we paste into.
//

import SwiftUI

struct RecordingOverlay: View {
    @ObservedObject var controller: RecordingController

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.red)

            WaveformView(level: controller.inputLevel)
                .frame(maxWidth: .infinity)
                .id(controller.sessionID)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(width: 240, height: 64)
        .background(.black.opacity(0.78), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
    }
}

#Preview {
    RecordingOverlay(controller: RecordingController(settings: SettingsStore(), history: HistoryStore()))
        .padding(40)
}
