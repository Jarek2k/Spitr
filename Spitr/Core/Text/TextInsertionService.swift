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
import ApplicationServices
import Carbon.HIToolbox
import os

private let log = Logger(subsystem: "com.jarek.Spitr", category: "insertion")

final class TextInsertionService {
    /// Virtual key code for "V" on an ANSI/QWERTY layout (kVK_ANSI_V).
    private let keyV: CGKeyCode = 9

    /// Delay before restoring the previous clipboard, giving the target app
    /// time to read the paste.
    private let restoreDelay: TimeInterval = 0.15

    /// Marks our temporary clipboard payload so clipboard-history managers
    /// (Raycast, Maccy, …) skip it — the dictated text may be a secret and we
    /// only park it for the duration of one paste.
    private let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    /// The clipboard we still owe a restore. Held so a quit/terminate inside the
    /// restore window doesn't leave the dictated text on the pasteboard.
    private var pendingRestore: [[NSPasteboard.PasteboardType: Data]]?

    /// When on, normalize spacing and add a leading space if the text would
    /// otherwise butt up against the preceding word. Set from Settings.
    var smartSpacing = true

    private var terminateObserver: NSObjectProtocol?

    init() {
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.restoreBeforeTerminate()
        }
    }

    deinit {
        if let terminateObserver {
            NotificationCenter.default.removeObserver(terminateObserver)
        }
    }

    func insert(_ text: String) {
        guard !text.isEmpty else { return }

        // Read cursor context *before* touching the clipboard/focus.
        let prepared = smartSpacing ? smartSpaced(text) : text
        guard !prepared.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let saved = snapshot(pasteboard)
        pendingRestore = saved

        pasteboard.clearContents()
        pasteboard.setString(prepared, forType: .string)
        // Empty marker: presence of the type is the signal, not its contents.
        pasteboard.setData(Data(), forType: concealedType)

        if cgEventPasteIsLayoutSafe() {
            pasteViaCGEvent()
        } else {
            log.info("non-QWERTY layout, pasting via AppleScript")
            pasteViaAppleScript()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) { [weak self] in
            guard let self, let saved = self.pendingRestore else { return }
            self.restore(saved, to: pasteboard)
            self.pendingRestore = nil
        }
    }

    /// Last-chance synchronous restore if the app is quitting while a paste's
    /// clipboard restore is still pending.
    private func restoreBeforeTerminate() {
        guard let saved = pendingRestore else { return }
        restore(saved, to: .general)
        pendingRestore = nil
    }

    // MARK: - Smart spacing

    /// Collapses runs of spaces/tabs, then prepends a space when the text would
    /// otherwise stick to the preceding word (decided from the caret context).
    private func smartSpaced(_ text: String) -> String {
        let collapsed = text.replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)
        return leadingSpaceNeeded(for: collapsed) ? " " + collapsed : collapsed
    }

    private func leadingSpaceNeeded(for text: String) -> Bool {
        guard let first = text.first, !first.isWhitespace else { return false }
        // Punctuation that attaches to the previous word should never get a space.
        if ".,;:!?)]}".contains(first) { return false }
        guard let prev = precedingCharacter() else { return false }   // unknown → don't guess
        if prev.isWhitespace { return false }
        // Don't separate from an opening bracket/quote either.
        if "([{".contains(prev) || "\u{201C}\u{201E}\u{2018}\u{00AB}".unicodeScalars.contains(where: { prev.unicodeScalars.contains($0) }) {
            return false
        }
        return true
    }

    /// Best-effort read of the character immediately before the caret in the
    /// focused text element, via Accessibility. Returns nil when unavailable —
    /// many Electron/Chromium editors don't expose text ranges, in which case we
    /// skip context-aware spacing rather than guessing wrong.
    private func precedingCharacter() -> Character? {
        let system = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        // CFGetTypeID guard + force cast is the correct idiom: `as?` to a CF type
        // doesn't actually type-check ("always succeeds"), so the type check has
        // to be explicit and the cast is then provably safe.
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement

        var rangeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        var selected = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &selected), selected.location > 0 else { return nil }

        var before = CFRange(location: selected.location - 1, length: 1)
        guard let beforeValue = AXValueCreate(.cfRange, &before) else { return nil }
        var substring: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(
                element, kAXStringForRangeParameterizedAttribute as CFString, beforeValue, &substring) == .success,
              let str = substring as? String else { return nil }
        return str.last
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
