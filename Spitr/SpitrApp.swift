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
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = RecordingController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.activate()
    }
}

/// Observes the controller so the status-bar glyph tracks recording state.
private struct MenuBarLabel: View {
    @ObservedObject var controller: RecordingController

    var body: some View {
        Image(systemName: controller.menuBarSymbol)
    }
}
