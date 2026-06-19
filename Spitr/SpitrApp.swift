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

extension Notification.Name {
    /// Posted from the menu to (re)open the permission onboarding window.
    static let showOnboarding = Notification.Name("com.jarek.Spitr.showOnboarding")
}

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
            SettingsView(settings: appDelegate.settings, history: appDelegate.history, dictionary: appDelegate.dictionary)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = SettingsStore()
    let history = HistoryStore()
    let dictionary = DictionaryStore()
    lazy var controller = RecordingController(settings: settings, history: history, dictionary: dictionary)

    private var onboardingWindow: NSWindow?

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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowOnboarding),
            name: .showOnboarding,
            object: nil
        )

        if !settings.hasCompletedOnboarding {
            showOnboarding()
        }
    }

    @objc private func handleShowOnboarding() {
        if let onboardingWindow {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            onboardingWindow.makeKeyAndOrderFront(nil)
            onboardingWindow.orderFrontRegardless()
        } else {
            showOnboarding()
        }
    }

    /// Presents the first-launch permission flow in its own window, briefly
    /// becoming a regular app so it gets a real, focusable window.
    private func showOnboarding() {
        let view = OnboardingView(controller: controller) { [weak self] in
            self?.onboardingWindow?.close()
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Willkommen bei Spitr"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        onboardingWindow = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    /// While a managed window is open, become a regular app so it appears in
    /// Cmd-Tab and the Dock; drop back to accessory once it closes.
    @objc private func windowWillClose(_ note: Notification) {
        guard let window = note.object as? NSWindow else { return }

        if window == onboardingWindow {
            settings.hasCompletedOnboarding = true
            onboardingWindow = nil
            NSApp.setActivationPolicy(.accessory)
            return
        }

        if isSettingsWindow(window) {
            NSApp.setActivationPolicy(.accessory)
        }
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
