//
//  OverlayController.swift
//  Spitr
//
//  Owns the borderless floating panel that hosts the recording overlay and
//  shows/hides it in lockstep with the recording state. The panel is a
//  non-activating panel that ignores mouse events, so it never takes focus
//  away from the app we paste the transcript into.
//

import AppKit
import SwiftUI
import Combine

@MainActor
final class OverlayController {
    private unowned let controller: RecordingController
    private var panel: NSPanel?
    private var cancellable: AnyCancellable?

    init(controller: RecordingController) {
        self.controller = controller
        cancellable = controller.$state
            .removeDuplicates()
            .sink { [weak self] state in self?.update(for: state) }
    }

    private func update(for state: RecordingController.State) {
        if state == .recording {
            show()
        } else {
            hide()
        }
    }

    private func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let size = NSSize(width: 240, height: 64)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let host = NSHostingView(rootView: RecordingOverlay(controller: controller))
        host.frame = NSRect(origin: .zero, size: size)
        panel.contentView = host
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.minY + 120
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
