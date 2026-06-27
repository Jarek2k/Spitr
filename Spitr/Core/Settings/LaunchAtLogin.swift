//
//  LaunchAtLogin.swift
//  Spitr
//
//  Thin wrapper around SMAppService for the "start Spitr at login" toggle.
//  SMAppService owns the persisted state itself (registered with launchd), so
//  this reads the live status rather than mirroring it into UserDefaults.
//

import ServiceManagement

enum LaunchAtLogin {

    private static let log = DiagLog(category: "LaunchAtLogin", subsystem: "com.spitr.app")

    /// True when the app is registered to start at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register or unregister the main app as a login item. Failures are logged
    /// and swallowed — a missing autostart is not worth crashing the app over.
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("Failed to \(enabled ? "register" : "unregister") login item: \(error.localizedDescription)")
        }
    }
}
