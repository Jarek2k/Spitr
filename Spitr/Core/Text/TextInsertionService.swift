//
//  TextInsertionService.swift
//  Spitr
//
//  Inserts transcribed text into whatever app is frontmost, by putting it on
//  the pasteboard and synthesizing ⌘V, then restoring the previous clipboard.
//
//  Synthesizing key events requires Accessibility permission.
//  Modeled on VoiceInk's CursorPaster. A full multi-type clipboard snapshot is
//  a v2 refinement — for now we preserve plain-text contents.
//

import AppKit

final class TextInsertionService {
    /// Virtual key code for "V" (kVK_ANSI_V).
    private let keyV: CGKeyCode = 9

    /// Delay before restoring the previous clipboard, giving the target app
    /// time to read the paste.
    private let restoreDelay: TimeInterval = 0.15

    func insert(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        paste()

        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
            pasteboard.clearContents()
            if let previous {
                pasteboard.setString(previous, forType: .string)
            }
        }
    }

    private func paste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        up?.flags = .maskCommand

        let tap: CGEventTapLocation = .cgAnnotatedSessionEventTap
        down?.post(tap: tap)
        up?.post(tap: tap)
    }
}
