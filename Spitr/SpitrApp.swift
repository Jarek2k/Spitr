//
//  SpitrApp.swift
//  Spitr
//
//  Menu-bar-only app (LSUIElement). The icon reflects recording state; the
//  dropdown hosts status, hotkey hint and permission setup.
//

import SwiftUI

@main
struct SpitrApp: App {
    @StateObject private var controller = RecordingController()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(controller: controller)
                .task { controller.activate() }
        } label: {
            Image(systemName: controller.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)
    }
}
