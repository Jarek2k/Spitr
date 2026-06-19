//
//  MenuContentView.swift
//  Spitr
//
//  The dropdown shown from the menu bar icon: status, hotkey hint, permission
//  setup, and Quit. Settings UI is a later milestone.
//

import SwiftUI

struct MenuContentView: View {
    @ObservedObject var controller: RecordingController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusRow

            Divider()

            Text("Halte \(controller.hotkeyConfig.displayName) und sprich.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            if !controller.allPermissionsGranted {
                Divider()
                permissionSection
            }

            Divider()

            SettingsLink {
                Text("Einstellungen…")
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",")
            // SettingsLink creates the window, but a menu-bar-only app runs as an
            // accessory, so it opens hidden. Activate and surface it explicitly.
            .simultaneousGesture(TapGesture().onEnded { surfaceSettingsWindow() })
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Button("Beenden") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .padding(.vertical, 6)
        .frame(width: 260)
        .onAppear { controller.refreshPermissions() }
    }

    /// Brings the SwiftUI settings window to the front. It opens hidden because
    /// the app is an accessory; switching to a regular app gives it a Dock icon
    /// and Cmd-Tab entry, then we activate and order it front once SwiftUI has
    /// had a run-loop turn to create it.
    private func surfaceSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let window = NSApp.windows.first(where: AppDelegate.isSettingsWindow)
            window?.makeKeyAndOrderFront(nil)
            window?.orderFrontRegardless()
        }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Image(systemName: controller.menuBarSymbol)
                .foregroundStyle(.tint)
            Text(controller.statusText)
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Berechtigungen")
                .font(.caption)
                .foregroundStyle(.secondary)

            permissionRow("Mikrofon", granted: controller.micGranted) {
                controller.requestMicrophone()
            }
            permissionRow("Spracherkennung", granted: controller.speechGranted) {
                controller.requestSpeech()
            }
            permissionRow("Bedienungshilfen", granted: controller.accessibilityTrusted) {
                controller.openAccessibility()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func permissionRow(_ label: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
            Text(label)
            Spacer()
            if !granted {
                Button("Erlauben", action: action)
                    .controlSize(.small)
            }
        }
    }
}
