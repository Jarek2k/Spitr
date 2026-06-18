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

/// Which physical key triggers recording. Defaults to the right Option key,
/// a modifier so holding it never types a character.
struct HotkeyConfig: Equatable {
    /// Physical key code (kVK_*). Right Option = 61.
    var keyCode: UInt16
    /// The modifier flag this key toggles.
    var flag: NSEvent.ModifierFlags
    /// Label for the UI, e.g. "⌥ rechts".
    var displayName: String

    static let rightOption = HotkeyConfig(keyCode: 61, flag: .option, displayName: "⌥ rechts")
}

/// Watches the system-wide keyboard for the configured hold key and reports
/// press/release. Callbacks fire on the main thread.
final class HotkeyService {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private(set) var config: HotkeyConfig
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isHeld = false

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
        isHeld = false
    }

    func update(config: HotkeyConfig) {
        self.config = config
        isHeld = false
    }

    private func handle(_ event: NSEvent) {
        // flagsChanged fires for every modifier transition; we only care about ours.
        guard event.keyCode == config.keyCode else { return }
        let pressed = event.modifierFlags.contains(config.flag)
        if pressed, !isHeld {
            isHeld = true
            onPress?()
        } else if !pressed, isHeld {
            isHeld = false
            onRelease?()
        }
    }

    deinit { stop() }
}
