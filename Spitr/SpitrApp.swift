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
    /// Posted from the Help menu to open the in-app usage guide.
    static let showHelp = Notification.Name("com.jarek.Spitr.showHelp")
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
        .commands {
            // The standard About panel pulls its icon from LaunchServices, which
            // ignores applicationIconImage and shows a stale/placeholder icon for
            // accessory apps. Pass the bundled icon and a short credits blurb so
            // the panel isn't just an icon and a version number.
            CommandGroup(replacing: .appInfo) {
                Button("Über Spitr") {
                    NSApp.orderFrontStandardAboutPanel(options: AppDelegate.aboutPanelOptions())
                }
            }

            // Spitr offers no system services and its targets are mostly Electron
            // apps where the Services menu does nothing useful — remove the noise.
            CommandGroup(replacing: .systemServices) {}

            // Replace the dead default "Spitr Help" (no help book → broken link)
            // with our own on-device usage guide.
            CommandGroup(replacing: .help) {
                Button("Spitr-Hilfe") {
                    NotificationCenter.default.post(name: .showHelp, object: nil)
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }

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
    private var helpWindow: NSWindow?

    /// Loads the bundled app icon directly, bypassing the LaunchServices icon
    /// cache that otherwise hands back a stale placeholder for accessory apps.
    static func bundleIcon() -> NSImage? {
        NSImage(named: "AppIcon")
            ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap(NSImage.init(contentsOf:))
    }

    /// Options for the standard About panel: the bundled icon (LaunchServices
    /// would otherwise show a placeholder for an accessory app) plus a one-line
    /// credits blurb. Name, version, build and copyright come from Info.plist.
    static func aboutPanelOptions() -> [NSApplication.AboutPanelOptionKey: Any] {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [:]
        if let icon = bundleIcon() {
            options[.applicationIcon] = icon
        }
        let blurb = String(localized: "Beta — On-device Voice-to-Text für macOS.\nTaste halten, sprechen, einfügen — privat, kostenlos, ohne Cloud.")
        options[.credits] = NSAttributedString(
            string: blurb,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        return options
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start persisting our own log to ~/Library/Logs/Spitr so a multi-day
        // session can be reviewed afterwards (errors, timings, optional resource
        // samples). Stopped with a final flush in applicationWillTerminate.
        LogStore.shared.start(verbose: settings.verboseLogging)

        // Drives the Dock icon while the app is briefly .regular (settings open).
        if let icon = Self.bundleIcon() {
            NSApp.applicationIconImage = icon
        }

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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowHelp),
            name: .showHelp,
            object: nil
        )

        installHelpShortcutMonitor()
        installWindowCloseMonitor()

        if !settings.hasCompletedOnboarding {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        LogStore.shared.stop()
    }

    private var helpShortcutMonitor: Any?
    private var escCloseMonitor: Any?

    /// macOS reserves Cmd-? (Cmd-Shift-/) for the Help menu's search field, so a
    /// plain `.keyboardShortcut("?")` on our menu item never fires — the search
    /// field swallows it first. We intercept the key down before AppKit routes
    /// it to Help and open our own guide instead. Layout-robust: matches the
    /// "?" character however the keyboard produces it.
    private func installHelpShortcutMonitor() {
        helpShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.command) else { return event }
            if event.characters == "?" || event.charactersIgnoringModifiers == "?" {
                self?.handleShowHelp()
                return nil // swallow so macOS doesn't open its Help search field
            }
            return event
        }
    }

    /// Lets Esc and Cmd-W close any of our own windows (onboarding, help,
    /// settings), which AppKit doesn't wire up for plain titled windows that have
    /// no File/Close menu. Scoped to our windows so both keys keep their normal
    /// meaning everywhere else.
    private func installWindowCloseMonitor() {
        escCloseMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  let window = NSApp.keyWindow,
                  window == self.onboardingWindow || window == self.helpWindow || Self.isSettingsWindow(window)
            else { return event }
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let isEsc = event.keyCode == 53 && mods.isEmpty
            let isCmdW = event.keyCode == 13 && mods == .command // 13 = "w"
            guard isEsc || isCmdW else { return event }
            window.performClose(nil)
            return nil
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
        window.title = String(localized: "Willkommen bei Spitr")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        onboardingWindow = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    @objc private func handleShowHelp() {
        if let helpWindow {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            helpWindow.makeKeyAndOrderFront(nil)
            helpWindow.orderFrontRegardless()
        } else {
            showHelp()
        }
    }

    /// Presents the on-device usage guide in its own window, briefly becoming a
    /// regular app so it gets a real, focusable window (same as onboarding).
    private func showHelp() {
        let window = NSWindow(contentViewController: NSHostingController(rootView: HelpView()))
        window.title = String(localized: "Spitr-Hilfe")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        helpWindow = window

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
        } else if window == helpWindow {
            helpWindow = nil
        } else if !isSettingsWindow(window) {
            return
        }

        // Drop back to a menu-bar accessory only once the last of our managed
        // windows is gone. With Settings and Help open at the same time, closing
        // one must not strip the other of its Dock icon / Cmd-Tab entry / menu.
        let othersOpen = NSApp.windows.contains { other in
            other != window && other.isVisible &&
            (other == onboardingWindow || other == helpWindow || Self.isSettingsWindow(other))
        }
        if !othersOpen {
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
