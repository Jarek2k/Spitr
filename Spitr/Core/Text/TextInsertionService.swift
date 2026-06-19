//
//  TextInsertionService.swift
//  Spitr
//
//  Inserts transcribed text into the frontmost app by putting it on the
//  pasteboard and synthesizing ⌘V, then restoring the previous clipboard.
//
//  Synthesizing key events requires Accessibility permission. Modeled on
//  VoiceInk's CursorPaster:
//  • the full pasteboard (all item types) is snapshotted and restored, not just
//    plain text, so images/rich content survive a paste;
//  • on non-QWERTY layouts where key code 9 isn't "v", we fall back to an
//    AppleScript keystroke, which maps the character via the active layout
//    (this triggers a one-time Automation prompt only for those users).
//

import AppKit
import Carbon.HIToolbox
import os

private let log = Logger(subsystem: "com.jarek.Spitr", category: "insertion")

final class TextInsertionService {
    /// Virtual key code for "V" on an ANSI/QWERTY layout (kVK_ANSI_V).
    private let keyV: CGKeyCode = 9

    /// Delay before restoring the previous clipboard, giving the target app
    /// time to read the paste.
    private let restoreDelay: TimeInterval = 0.15

    func insert(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let saved = snapshot(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        if cgEventPasteIsLayoutSafe() {
            pasteViaCGEvent()
        } else {
            log.info("non-QWERTY layout, pasting via AppleScript")
            pasteViaAppleScript()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) { [weak self] in
            self?.restore(saved, to: pasteboard)
        }
    }

    // MARK: - Paste

    private func pasteViaCGEvent() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        up?.flags = .maskCommand

        let tap: CGEventTapLocation = .cgAnnotatedSessionEventTap
        down?.post(tap: tap)
        up?.post(tap: tap)
    }

    private func pasteViaAppleScript() {
        let source = "tell application \"System Events\" to keystroke \"v\" using command down"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            log.error("AppleScript paste failed: \(error, privacy: .public)")
        }
    }

    /// True when key code 9 produces "v" on the active keyboard layout, so the
    /// fast CGEvent path types the right character.
    private func cgEventPasteIsLayoutSafe() -> Bool {
        character(for: keyV) == "v"
    }

    /// Translates a virtual key code to its character on the current layout.
    private func character(for keyCode: CGKeyCode) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPtr).takeUnretainedValue() as Data

        return layoutData.withUnsafeBytes { raw -> String? in
            guard let keyLayout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress
            else { return nil }

            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = UCKeyTranslate(
                keyLayout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDown),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars)

            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length)
        }
    }

    // MARK: - Clipboard snapshot / restore

    /// Captures every item with all of its types so any content survives.
    private func snapshot(_ pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        pasteboard.pasteboardItems?.map { item in
            var entry: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    entry[type] = data
                }
            }
            return entry
        } ?? []
    }

    private func restore(_ snapshot: [[NSPasteboard.PasteboardType: Data]], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !snapshot.isEmpty else { return }

        let items = snapshot.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(items)
    }
}
