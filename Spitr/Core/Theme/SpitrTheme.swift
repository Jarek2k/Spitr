//
//  SpitrTheme.swift
//  Spitr
//
//  The one place that owns Spitr's visual identity — the "signal" palette from
//  the product site. Views reference these tokens instead of hardcoding hex, so
//  re-skinning is a single-file change. Kept deliberately small: brand accent,
//  the dark surfaces and a few text tints. Used tastefully, not everywhere —
//  the brand green marks *activity* (recording, selection), not whole windows.
//

import SwiftUI

enum SpitrTheme {
    /// Spring-green brand accent (#4ef0a6). The signature colour.
    static let brand = Color(red: 78 / 255, green: 240 / 255, blue: 166 / 255)
    /// Slightly deeper green for light backgrounds where the bright accent would
    /// glare or wash out (#2bc98c).
    static let brandDeep = Color(red: 43 / 255, green: 201 / 255, blue: 140 / 255)
    /// Near-black ink that sits *on* the brand accent (#06120c) — dark text on a
    /// green pill, exactly like the site's buttons. White on green reads poorly.
    static let onBrand = Color(red: 6 / 255, green: 18 / 255, blue: 12 / 255)

    /// Darkest surface (#08090a) and the panel one step up (#0e1011).
    static let background = Color(red: 8 / 255, green: 9 / 255, blue: 10 / 255)
    static let panel = Color(red: 14 / 255, green: 16 / 255, blue: 17 / 255)

    /// Off-white primary text (#f3f5f4) and the muted/faint greys.
    static let ink = Color(red: 243 / 255, green: 245 / 255, blue: 244 / 255)
    static let muted = Color(red: 138 / 255, green: 144 / 255, blue: 141 / 255)
    static let faint = Color(red: 89 / 255, green: 95 / 255, blue: 92 / 255)

    /// Hairline divider/border tint.
    static let line = Color.white.opacity(0.09)
}
