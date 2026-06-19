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
    private var cancellables = Set<AnyCancellable>()

    init(controller: RecordingController) {
        self.controller = controller
        // Visible while recording, or briefly while a command result is shown.
        Publishers.CombineLatest(
            controller.$state.removeDuplicates(),
            controller.$commandFeedback.removeDuplicates()
        )
        .sink { [weak self] state, feedback in
            self?.update(recording: state == .recording, hasFeedback: feedback != nil)
        }
        .store(in: &cancellables)
    }

    private func update(recording: Bool, hasFeedback: Bool) {
        if recording || hasFeedback {
            show()
        } else {
            hide()
        }
    }

    /// Capsule presentation vs. the larger, chrome-free strands animation.
    private static let capsuleSize = NSSize(width: 240, height: 64)
    private static let strandsSize = NSSize(width: 300, height: 100)

    private func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        let strandsOnly = controller.overlayIsStrandsOnly
        let size = strandsOnly ? Self.strandsSize : Self.capsuleSize
        if panel.frame.size != size {
            panel.setContentSize(size)
        }
        // No drop shadow behind the bare animation — only the capsule wants one.
        panel.hasShadow = !strandsOnly
        panel.invalidateShadow()
        position(panel)
        panel.orderFrontRegardless()
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let size = Self.capsuleSize
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
        host.autoresizingMask = [.width, .height]
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
