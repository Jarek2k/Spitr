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

            Divider().padding(.horizontal, 10)

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
                Divider().padding(.horizontal, 10)
                permissionSection
            }

            Divider().padding(.horizontal, 10)

            VStack(alignment: .leading, spacing: 1) {
                MenuButton { controller.togglePause() } label: { hl in
                    Text(controller.paused ? "Fortsetzen" : "Pausieren")
                        .foregroundStyle(hl ? Color.white : Color.primary)
                }

                MenuButton { controller.reinsertLast() } label: { hl in
                    HStack {
                        Text("Letztes Diktat erneut einfügen")
                        Spacer()
                        Text(controller.reinsertShortcutLabel)
                            .foregroundStyle(hl ? Color.white.opacity(0.7) : Color.secondary)
                    }
                    .foregroundStyle(hl ? Color.white : Color.primary)
                }
                .disabled(controller.lastInsertedText == nil)
                .help("Fügt das zuletzt erkannte Diktat erneut ins fokussierte Feld ein — z. B. wenn der Fokus vorher falsch war. Geht überall per \(controller.reinsertShortcutLabel).")

                MenuButton {
                    NotificationCenter.default.post(name: .showOnboarding, object: nil)
                } label: { hl in
                    Text("Einrichtung…")
                        .foregroundStyle(hl ? Color.white : Color.primary)
                }

                // SettingsLink creates the window, but a menu-bar-only app runs as
                // an accessory, so it opens hidden. Activate and surface it after.
                SettingsLink {
                    Text("Einstellungen…")
                }
                .buttonStyle(.plain)
                .keyboardShortcut(",")
                .modifier(MenuRowStyle())
                .simultaneousGesture(TapGesture().onEnded { surfaceSettingsWindow() })

                MenuButton { NSApp.terminate(nil) } label: { hl in
                    Text("Spitr beenden")
                        .foregroundStyle(hl ? Color.white : Color.primary)
                }
                .keyboardShortcut("q")
            }
            .padding(.horizontal, 5)
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

/// A full-width menu row that highlights on hover like a native AppKit menu
/// item — accent fill with white text. The label closure receives the current
/// highlight state so nested text (e.g. a trailing shortcut) can recolor too.
/// Disabled rows dim and never highlight.
private struct MenuButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder var label: (Bool) -> Label

    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    private var highlighted: Bool { hovering && isEnabled }

    var body: some View {
        Button(action: action) {
            label(highlighted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(highlighted ? Color.accentColor : .clear)
        )
        .opacity(isEnabled ? 1 : 0.35)
        .onHover { hovering = $0 }
    }
}

/// Same hover/highlight chrome as `MenuButton`, but as a modifier so it can wrap
/// controls that aren't plain Buttons (e.g. `SettingsLink`).
private struct MenuRowStyle: ViewModifier {
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    private var highlighted: Bool { hovering && isEnabled }

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .foregroundStyle(highlighted ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(highlighted ? Color.accentColor : .clear)
            )
            .opacity(isEnabled ? 1 : 0.35)
            .onHover { hovering = $0 }
    }
}
