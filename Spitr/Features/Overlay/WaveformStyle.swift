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
    /// Lightweight SwiftUI Canvas: mirrored scrolling bars (the original).
    case bars
    /// GPU "strands": flowing sine threads rendered by a Metal shader.
    case strands
    /// KITT-style red segmented voice box (Knight Rider).
    case kitt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bars:    return String(localized: "Balken")
        case .strands: return String(localized: "Strähnen (Metal)")
        case .kitt:    return String(localized: "KITT (rot)")
        }
    }
}
