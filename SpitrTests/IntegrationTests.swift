//
//  IntegrationTests.swift
//  SpitrTests
//
//  Cross-module behaviour: the dictionary → replacement post-processing pipeline,
//  and the RecordingController wiring (pause mirror, strands-only overlay) without
//  touching audio hardware.
//

import Testing
import Foundation
@testable import Spitr

@MainActor
struct PostProcessingPipelineTests {

    @Test func dictionaryAppliesOnlyWhenEnabled() {
        let dict = DictionaryStore(defaults: makeDefaults())
        dict.add()
        dict.update(ReplacementRule(id: dict.rules[0].id, pattern: "klode", replacement: "Claude"))
        let service = TextReplacementService()

        // Disabled → no active rules → text untouched.
        #expect(service.apply(dict.activeRules, to: "frag Klode") == "frag Klode")

        // Enabled → rule applies.
        dict.isEnabled = true
        #expect(service.apply(dict.activeRules, to: "frag Klode") == "frag Claude")
    }
}

@MainActor
struct RecordingControllerWiringTests {

    private func makeController() -> (RecordingController, SettingsStore) {
        let d = makeDefaults()
        let settings = SettingsStore(defaults: d)
        let controller = RecordingController(
            settings: settings,
            history: HistoryStore(defaults: d),
            dictionary: DictionaryStore(defaults: d)
        )
        return (controller, settings)
    }

    @Test func togglePauseMirrorsIntoController() {
        let (controller, settings) = makeController()
        #expect(controller.paused == false)
        controller.togglePause()
        #expect(settings.isPaused == true)
        #expect(controller.paused == true)
        controller.togglePause()
        #expect(controller.paused == false)
    }

    @Test func chromelessTracksStyleAndMode() {
        let (controller, settings) = makeController()
        #expect(controller.overlayIsChromeless == false)   // default bars → capsule
        settings.waveformStyle = .strands
        #expect(controller.overlayIsChromeless == true)    // strands → chrome-free
        settings.waveformStyle = .kitt
        #expect(controller.overlayIsChromeless == true)    // KITT → chrome-free
        settings.waveformStyle = .bars
        #expect(controller.overlayIsChromeless == false)
    }
}
