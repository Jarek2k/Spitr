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

            VStack(alignment: .leading, spacing: 2) {
                Text("Halte \(controller.hotkeyConfig.displayName) und sprich.")
                Text("Mit ⇧ dazu: Befehlsmodus (z. B. »pause«, »weiter«).")
                    .foregroundStyle(.tertiary)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if !controller.allPermissionsGranted {
                Divider()
                permissionSection
            }

            Divider()

            Button(controller.paused ? "Fortsetzen" : "Pausieren") {
                controller.togglePause()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Button {
                controller.reinsertLast()
            } label: {
                HStack {
                    Text("Letztes Diktat erneut einfügen")
                    Spacer()
                    Text(controller.reinsertShortcutLabel)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .disabled(controller.lastInsertedText == nil)
            .help("Fügt das zuletzt erkannte Diktat erneut ins fokussierte Feld ein — z. B. wenn der Fokus vorher falsch war. Geht überall per \(controller.reinsertShortcutLabel).")
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Button("Einrichtung…") {
                NotificationCenter.default.post(name: .showOnboarding, object: nil)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

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
        Task { @MainActor in
            NSApp.setActivationPolicy(.regular)
            // macOS resets the Dock icon to the (stale) bundle icon on the policy
            // switch, so re-apply our bundled icon now that a Dock icon exists.
            if let icon = AppDelegate.bundleIcon() {
                NSApp.applicationIconImage = icon
            }

            // A single run-loop hop isn't enough: macOS needs real delays to let
            // SwiftUI create the settings window before we can surface it.
            try? await Task.sleep(for: .milliseconds(100))
            NSApp.activate(ignoringOtherApps: true)
            try? await Task.sleep(for: .milliseconds(200))
            let window = NSApp.windows.first(where: AppDelegate.isSettingsWindow)
            window?.makeKeyAndOrderFront(nil)
            window?.orderFrontRegardless()

            // Known macOS bug: after switching an accessory app to .regular, the
            // app menu stays unclickable/missing until focus leaves the app and
            // returns. Force that by briefly activating the Dock, then ourselves.
            // (See ar.al unclickable-app-menu workaround.)
            if let dock = NSRunningApplication.runningApplications(
                withBundleIdentifier: "com.apple.dock").first {
                dock.activate(options: [])
                try? await Task.sleep(for: .milliseconds(200))
                NSApp.activate(ignoringOtherApps: true)
                window?.makeKeyAndOrderFront(nil)
            }
        }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Image(systemName: controller.menuBarSymbol)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(controller.statusText)
                    .font(.headline)
                Text(controller.activeEngineLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
