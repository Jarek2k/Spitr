//
//  KeyCombo.swift
//  Spitr
//
//  A configurable global shortcut: a key plus modifier flags. `label` is the
//  base character captured when the user recorded the combo, so display never
//  needs to translate key codes back to glyphs.
//

import AppKit

struct KeyCombo: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags
    var label: String

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, label: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.label = label
    }

    /// Only the four modifiers we care about, so stray flags (capslock, fn,
    /// numeric pad) never affect matching or equality.
    static let relevantMask: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    /// True when `event` is exactly this chord.
    func matches(_ event: NSEvent) -> Bool {
        event.keyCode == keyCode
            && event.modifierFlags.intersection(Self.relevantMask) == modifiers.intersection(Self.relevantMask)
    }

    /// At least one of ⌘/⌃/⌥ — bare or Shift-only chords trigger far too easily.
    var isValid: Bool {
        !modifiers.intersection([.command, .control, .option]).isEmpty
    }

    /// e.g. "⌃⌥⌘V" (conventional glyph order ⌃⌥⇧⌘).
    var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option)  { s += "⌥" }
        if modifiers.contains(.shift)   { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + label.uppercased()
    }

    static let reinsertDefault = KeyCombo(keyCode: 9, modifiers: [.control, .option, .command], label: "v")

    // MARK: - Codable (NSEvent.ModifierFlags via rawValue)

    private enum CodingKeys: String, CodingKey { case keyCode, modifiers, label }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try c.decode(UInt16.self, forKey: .keyCode)
        modifiers = NSEvent.ModifierFlags(rawValue: try c.decode(UInt.self, forKey: .modifiers))
        label = try c.decode(String.self, forKey: .label)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(keyCode, forKey: .keyCode)
        try c.encode(modifiers.rawValue, forKey: .modifiers)
        try c.encode(label, forKey: .label)
    }
}
