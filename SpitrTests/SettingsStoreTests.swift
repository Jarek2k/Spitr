//
//  SettingsStoreTests.swift
//  SpitrTests
//

import Testing
import Foundation
@testable import Spitr

@MainActor
struct SettingsStoreTests {

    @Test func defaultsAreSane() {
        let s = SettingsStore(defaults: makeDefaults())
        #expect(s.engineKind == .apple)
        #expect(s.localeIdentifier == "de-DE")
        #expect(s.hotkeyKeyCode == HotkeyConfig.rightOption.keyCode)
        #expect(s.whisperModel == WhisperKitEngine.defaultModel)
        #expect(s.inputDeviceUID == "")
        #expect(s.hasCompletedOnboarding == false)
        #expect(s.waveformStyle == .signalReactive)
        #expect(s.vocabularyText == "")
        #expect(s.isPaused == false)
    }

    @Test func valuesPersistAcrossInstances() {
        let defaults = makeDefaults()
        let first = SettingsStore(defaults: defaults)
        first.engineKind = .whisperKit
        first.localeIdentifier = "en-US"
        first.hotkeyKeyCode = HotkeyConfig.function.keyCode
        first.whisperModel = "small"
        first.inputDeviceUID = "mic-123"
        first.hasCompletedOnboarding = true
        first.waveformStyle = .strands
        first.vocabularyText = "Claude"

        let second = SettingsStore(defaults: defaults)
        #expect(second.engineKind == .whisperKit)
        #expect(second.localeIdentifier == "en-US")
        #expect(second.hotkeyKeyCode == HotkeyConfig.function.keyCode)
        #expect(second.whisperModel == "small")
        #expect(second.inputDeviceUID == "mic-123")
        #expect(second.hasCompletedOnboarding == true)
        #expect(second.waveformStyle == .strands)
        #expect(second.vocabularyText == "Claude")
    }

    @Test func isPausedIsNotPersisted() {
        let defaults = makeDefaults()
        let first = SettingsStore(defaults: defaults)
        first.isPaused = true
        // Transient session state must not leak into a fresh launch.
        let second = SettingsStore(defaults: defaults)
        #expect(second.isPaused == false)
    }

    @Test func localeDerivesFromIdentifier() {
        let s = SettingsStore(defaults: makeDefaults())
        s.localeIdentifier = "en-GB"
        #expect(s.locale.identifier == "en-GB")
    }

    @Test func vocabularyTrimsAndDropsEmptyLines() {
        let s = SettingsStore(defaults: makeDefaults())
        s.vocabularyText = "Claude\n  Xcode  \n\n\t\nSwiftUI "
        #expect(s.vocabulary == ["Claude", "Xcode", "SwiftUI"])
    }

    @Test func emptyVocabularyIsEmptyArray() {
        let s = SettingsStore(defaults: makeDefaults())
        s.vocabularyText = "   \n\n  "
        #expect(s.vocabulary.isEmpty)
    }
}
