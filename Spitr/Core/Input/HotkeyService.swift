//
//  HotkeyService.swift
//  Spitr
//
//  Global Hold-to-Talk trigger. Records only while a modifier key is held —
//  press starts, release stops. Dependency-free (NSEvent monitors).
//
//  Receiving global key events requires Accessibility permission; without it
//  the monitors install silently but never fire (see PermissionService).
//

import AppKit
import os

/// Which physical key triggers recording. Defaults to the right Option key,
/// a modifier so holding it never types a character.
struct HotkeyConfig: Equatable {
    /// Physical key code (kVK_*). Right Option = 61.
    var keyCode: UInt16
    /// The modifier flag this key toggles.
    var flag: NSEvent.ModifierFlags
    /// Label for the UI, e.g. "⌥ rechts".
    var displayName: String

    static let rightOption  = HotkeyConfig(keyCode: 61, flag: .option,   displayName: "⌥ rechts")
    static let leftOption   = HotkeyConfig(keyCode: 58, flag: .option,   displayName: "⌥ links")
    static let rightControl = HotkeyConfig(keyCode: 62, flag: .control,  displayName: "⌃ rechts")
    static let leftControl  = HotkeyConfig(keyCode: 59, flag: .control,  displayName: "⌃ links")
    static let function     = HotkeyConfig(keyCode: 63, flag: .function, displayName: "fn")

    /// Modifier keys offered in Settings. Hold-to-Talk needs a modifier so the
    /// held key never types a character; Command/Shift are left out (shortcut
    /// clashes / caps behaviour).
    static let selectable: [HotkeyConfig] = [
        .rightOption, .leftOption, .rightControl, .leftControl, .function,
    ]

    /// Resolves a persisted key code back to a known config, defaulting safely.
    static func named(keyCode: UInt16) -> HotkeyConfig {
        selectable.first { $0.keyCode == keyCode } ?? .rightOption
    }
}

/// Watches the system-wide keyboard for the configured hold key and reports
/// press/release. Callbacks fire on the main thread.
final class HotkeyService {
    /// Fires on key-down. `commandMode` is true when Shift was held at that
    /// instant — the gesture that turns dictation into a voice command.
    var onPress: ((_ commandMode: Bool) -> Void)?
    var onRelease: (() -> Void)?
    /// Fires when Escape is pressed while the cancel watch is active (during a
    /// recording), so the controller can discard it instead of transcribing.
    var onCancel: (() -> Void)?

    /// Escape (kVK_Escape) — the abort key while holding to talk.
    private static let escapeKeyCode: UInt16 = 53

    private(set) var config: HotkeyConfig
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var cancelGlobalMonitor: Any?
    private var cancelLocalMonitor: Any?
    private var isHeld = false
    private let log = Logger(subsystem: "com.jarek.Spitr", category: "hotkey")

    init(config: HotkeyConfig = .rightOption) {
        self.config = config
    }

    var isRunning: Bool { globalMonitor != nil }

    func start() {
        guard globalMonitor == nil else { return }
        // Global monitor: events while *other* apps are focused (the common case).
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
        }
        // Local monitor: events while Spitr itself is focused.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        endCancelWatch()
        isHeld = false
    }

    /// Starts watching for Escape, only while a recording is in flight. Installed
    /// on demand (not always-on) so we don't observe every keystroke system-wide
    /// outside of an active recording.
    func beginCancelWatch() {
        guard cancelGlobalMonitor == nil else { return }
        cancelGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == Self.escapeKeyCode else { return }
            self?.onCancel?()
        }
        // When Spitr itself is focused, also swallow the Escape so it doesn't ring.
        cancelLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == Self.escapeKeyCode else { return event }
            self?.onCancel?()
            return nil
        }
    }

    func endCancelWatch() {
        if let cancelGlobalMonitor { NSEvent.removeMonitor(cancelGlobalMonitor) }
        if let cancelLocalMonitor { NSEvent.removeMonitor(cancelLocalMonitor) }
        cancelGlobalMonitor = nil
        cancelLocalMonitor = nil
    }

    func update(config: HotkeyConfig) {
        self.config = config
        isHeld = false
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags
        // Recovery: global NSEvent monitors are best-effort and can drop events
        // under load (e.g. video playback). If we think the key is held but its
        // modifier is absent from *any* flagsChanged event, the release was lost
        // — close the stale session so the next press isn't swallowed.
        if isHeld, !flags.contains(config.flag) {
            log.notice("recovered dropped release (stale isHeld)")
            isHeld = false
            onRelease?()
        }
        // flagsChanged fires for every modifier transition; we only care about ours.
        guard event.keyCode == config.keyCode else { return }
        if flags.contains(config.flag) {
            // A fresh key-down for our key. Modifiers don't auto-repeat, so seeing
            // this while still "held" means the prior release was lost: end the
            // stale session, then start fresh.
            if isHeld {
                log.notice("recovered dropped release (re-press while held)")
                onRelease?()
            }
            isHeld = true
            onPress?(flags.contains(.shift))
        } else if isHeld {
            isHeld = false
            onRelease?()
        }
    }

    deinit { stop() }
}
