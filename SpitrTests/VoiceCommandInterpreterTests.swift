//
//  VoiceCommandInterpreterTests.swift
//  SpitrTests
//
//  Integration-level: the interpreter is exercised against real SettingsStore,
//  HistoryStore and DictionaryStore instances, and we assert that matching a
//  spoken phrase actually flips the corresponding state.
//

import Testing
import Foundation
@testable import Spitr

@MainActor
struct VoiceCommandInterpreterTests {

    private func env() -> (VoiceCommandInterpreter, SettingsStore, HistoryStore, DictionaryStore) {
        let d = makeDefaults()
        return (VoiceCommandInterpreter(),
                SettingsStore(defaults: d),
                HistoryStore(defaults: d),
                DictionaryStore(defaults: d))
    }

    private func run(_ transcript: String,
                     _ i: VoiceCommandInterpreter,
                     _ s: SettingsStore, _ h: HistoryStore, _ dic: DictionaryStore) -> VoiceCommand? {
        let cmd = i.match(transcript, settings: s, history: h, dictionary: dic)
        cmd?.perform()
        return cmd
    }

    @Test func pauseAndResume() {
        let (i, s, h, d) = env()
        #expect(run("pause bitte", i, s, h, d)?.id == "pause")
        #expect(s.isPaused == true)
        #expect(run("mach mal weiter", i, s, h, d)?.id == "resume")
        #expect(s.isPaused == false)
    }

    @Test func switchEngines() {
        let (i, s, h, d) = env()
        #expect(run("wechsel zu whisperkit", i, s, h, d)?.id == "engineWhisper")
        #expect(s.engineKind == .whisperKit)
        #expect(run("nimm apple speech", i, s, h, d)?.id == "engineApple")
        #expect(s.engineKind == .apple)
    }

    @Test func offlineForcesAppleEngine() {
        let (i, s, h, d) = env()
        s.engineKind = .whisperKit
        #expect(run("offline modus", i, s, h, d)?.id == "offline")
        #expect(s.engineKind == .apple)
    }

    @Test func switchLanguage() {
        let (i, s, h, d) = env()
        #expect(run("sprache englisch", i, s, h, d)?.id == "langEN")
        #expect(s.localeIdentifier == "en-US")
        #expect(run("auf deutsch", i, s, h, d)?.id == "langDE")
        #expect(s.localeIdentifier == "de-DE")
    }

    @Test func toggleDictionary() {
        let (i, s, h, d) = env()
        d.isEnabled = true
        #expect(run("wörterbuch aus", i, s, h, d)?.id == "dictOff")
        #expect(d.isEnabled == false)
        #expect(run("wörterbuch an", i, s, h, d)?.id == "dictOn")
        #expect(d.isEnabled == true)
    }

    @Test func toggleHistory() {
        let (i, s, h, d) = env()
        #expect(run("verlauf aus", i, s, h, d)?.id == "histOff")
        #expect(h.isEnabled == false)
        #expect(run("verlauf an", i, s, h, d)?.id == "histOn")
        #expect(h.isEnabled == true)
    }

    @Test func matchingIsCaseInsensitive() {
        let (i, s, h, d) = env()
        #expect(i.match("PAUSE", settings: s, history: h, dictionary: d)?.id == "pause")
    }

    @Test func longerPhraseWinsOverShorter() {
        // "wörterbuch aus" must resolve to dictOff, never to a shorter accidental match.
        let (i, s, h, d) = env()
        #expect(i.match("bitte wörterbuch aus machen", settings: s, history: h, dictionary: d)?.id == "dictOff")
    }

    @Test func unknownTranscriptReturnsNil() {
        let (i, s, h, d) = env()
        #expect(i.match("erzähl mir einen witz", settings: s, history: h, dictionary: d) == nil)
    }

    @Test func everyCommandHasTitleAndExample() {
        let (i, s, h, d) = env()
        for c in i.commands(settings: s, history: h, dictionary: d) {
            #expect(!c.title.isEmpty)
            #expect(!c.example.isEmpty)
        }
    }
}
