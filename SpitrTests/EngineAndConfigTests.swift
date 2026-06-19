//
//  EngineAndConfigTests.swift
//  SpitrTests
//
//  Small value-type / factory units: EngineSelector, EngineKind, WaveformStyle,
//  HotkeyConfig.
//

import Testing
@testable import Spitr

struct EngineSelectorTests {

    @Test func buildsRequestedEngine() {
        let sel = EngineSelector()
        #expect(sel.makeEngine(.apple).id == "apple")
        #expect(sel.makeEngine(.whisperKit).id == "whisperkit")
    }

    @Test func defaultIsApple() {
        #expect(EngineSelector().defaultKind() == .apple)
    }

    @Test func engineKindCasesHaveNames() {
        #expect(EngineKind.allCases == [.apple, .whisperKit])
        for kind in EngineKind.allCases { #expect(!kind.displayName.isEmpty) }
    }
}

struct WaveformStyleTests {

    @Test func cases() {
        #expect(WaveformStyle.allCases == [.bars, .strands])
    }

    @Test func rawValueRoundTrips() {
        for style in WaveformStyle.allCases {
            #expect(WaveformStyle(rawValue: style.rawValue) == style)
            #expect(!style.displayName.isEmpty)
        }
    }
}

struct HotkeyConfigTests {

    @Test func namedResolvesKnownKeys() {
        #expect(HotkeyConfig.named(keyCode: 61) == .rightOption)
        #expect(HotkeyConfig.named(keyCode: 62) == .rightControl)
        #expect(HotkeyConfig.named(keyCode: 63) == .function)
    }

    @Test func namedFallsBackForUnknown() {
        #expect(HotkeyConfig.named(keyCode: 9999) == .rightOption)
    }

    @Test func selectableSet() {
        #expect(HotkeyConfig.selectable.count == 5)
        // No duplicate key codes.
        let codes = HotkeyConfig.selectable.map(\.keyCode)
        #expect(Set(codes).count == codes.count)
    }
}
