//
//  SpitrApp.swift
//  Spitr
//
//  Menu-bar-only app (LSUIElement). The icon reflects recording state; the
//  dropdown hosts status, hotkey hint and permission setup. The controller is
//  owned and activated by the AppDelegate so the hotkey listener starts at
//  launch — not lazily on the first menu click.
//

import SwiftUI

@main
struct SpitrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(controller: appDelegate.controller)
        } label: {
            MenuBarLabel(controller: appDelegate.controller)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: appDelegate.settings)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = SettingsStore()
    lazy var controller = RecordingController(settings: settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.activate()
        // Stay a menu-bar accessory by default (no Dock icon, no Cmd-Tab entry).
        NSApp.setActivationPolicy(.accessory)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    /// While the settings window is open, become a regular app so it appears in
    /// Cmd-Tab and the Dock; drop back to accessory once it closes.
    @objc private func windowWillClose(_ note: Notification) {
        guard let window = note.object as? NSWindow,
              isSettingsWindow(window) else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    static func isSettingsWindow(_ window: NSWindow) -> Bool {
        window.identifier?.rawValue.contains("Settings") == true
    }

    private func isSettingsWindow(_ window: NSWindow) -> Bool {
        Self.isSettingsWindow(window)
    }
}

/// Observes the controller so the status-bar glyph tracks recording state.
private struct MenuBarLabel: View {
    @ObservedObject var controller: RecordingController

    var body: some View {
        Image(systemName: controller.menuBarSymbol)
    }
}
