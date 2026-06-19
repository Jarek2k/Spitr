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
    @ObservedObject var settings: SettingsStore

    init(controller: RecordingController) {
        self.controller = controller
        self.settings = controller.settings
    }

    private var isCommand: Bool { controller.mode == .command }

    var body: some View {
        if controller.overlayIsStrandsOnly {
            // Bare animation: no capsule, no mic — fills the whole panel.
            MetalWaveformView(level: controller.inputLevel)
                .id(controller.sessionID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            chromed
        }
    }

    /// The capsule presentation: used for the bars waveform, command mode and
    /// the command result. The strands style opts out of this entirely.
    private var chromed: some View {
        Group {
            if let feedback = controller.commandFeedback, controller.state != .recording {
                commandResult(feedback)
            } else {
                recordingContent
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(width: 240, height: 64)
        .background(.black.opacity(0.78), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
    }

    private var recordingContent: some View {
        HStack(spacing: 12) {
            Image(systemName: isCommand ? "command.circle.fill" : "mic.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isCommand ? .yellow : .red)

            if isCommand {
                Text("Befehl…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                capsuleWaveform
                    .frame(maxWidth: .infinity)
                    .id(controller.sessionID)
            }
        }
    }

    private func commandResult(_ text: String) -> some View {
        let recognized = controller.lastCommandRecognized
        return HStack(spacing: 10) {
            Image(systemName: recognized ? "checkmark.circle.fill" : "questionmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(recognized ? .green : .orange)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The waveform shown inside the capsule (bars or KITT). Strands opts out of
    /// the capsule entirely via `overlayIsStrandsOnly`, so it never reaches here.
    @ViewBuilder
    private var capsuleWaveform: some View {
        switch settings.waveformStyle {
        case .kitt: KittWaveformView(level: controller.inputLevel)
        default:    WaveformView(level: controller.inputLevel)
        }
    }
}

#Preview {
    RecordingOverlay(controller: RecordingController(settings: SettingsStore(), history: HistoryStore(), dictionary: DictionaryStore()))
        .padding(40)
}
