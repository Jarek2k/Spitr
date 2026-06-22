//
//  WaveformStyle.swift
//  Spitr
//
//  The exchangeable decision "how does the recording waveform look". Adding a
//  style means one case here, one branch in RecordingOverlay, and one view —
//  nothing else needs to know which renderer is active.
//

import Foundation

enum WaveformStyle: String, CaseIterable, Identifiable {
    /// Voice-driven signal bars: each bar reacts independently to loudness, so
    /// the shape answers the voice instead of just scaling. The default.
    case signalReactive
    /// Brand "signal" bars, bare: a fixed jagged shape that scales with loudness.
    case signalBare
    /// Same bars inside the capsule (with mic glyph and border).
    case signal
    /// Lightweight SwiftUI Canvas: mirrored scrolling bars (the original).
    case bars
    /// KITT-style red segmented voice box (Knight Rider).
    case kitt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .signalReactive: return String(localized: "Signal (reaktiv)")
        case .signalBare:     return String(localized: "Signal (randlos)")
        case .signal:         return String(localized: "Signal (Kapsel)")
        case .bars:           return String(localized: "Balken")
        case .kitt:           return String(localized: "KITT (rot)")
        }
    }
}
