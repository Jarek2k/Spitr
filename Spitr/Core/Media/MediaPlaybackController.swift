//
//  MediaPlaybackController.swift
//  Spitr
//
//  Best-effort pause/resume of system media playback (Music, Spotify, browser
//  video, …) for the duration of a recording, so the dictation audio isn't
//  polluted and the user isn't talking over a song.
//
//  macOS exposes no public API to pause *other* apps' playback, so this bridges
//  the private MediaRemote framework via dlopen/dlsym. It only ever pauses when
//  something is actually playing and only resumes what *it* paused. If the
//  symbols can't be resolved — Apple tightened MediaRemote for third-party apps
//  in macOS 15.4 — every call degrades to a harmless no-op.
//
//  All methods are expected to be called on the main thread (the owning
//  RecordingController is @MainActor); the MediaRemote query also delivers its
//  completion on the main queue, so `didPause` is only ever touched there.
//

import Foundation
import os

private let log = Logger(subsystem: "com.jarek.Spitr", category: "media")

final class MediaPlaybackController {

    // MRMediaRemoteSendCommand(command, userInfo) -> Bool
    private typealias SendCommand = @convention(c) (Int, CFDictionary?) -> Bool
    // MRMediaRemoteGetNowPlayingApplicationIsPlaying(queue, completion(isPlaying))
    private typealias GetIsPlaying = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void

    // MRMediaRemoteCommand raw values.
    private let cmdPlay = 0
    private let cmdPause = 1

    private let sendCommand: SendCommand?
    private let getIsPlaying: GetIsPlaying?

    /// True while we hold a pause we issued, so we only resume our own pause.
    private var didPause = false

    /// Desired pause state. Guards the async `isPlaying` query against a fast
    /// key tap: if the recording already ended before the query returns, this is
    /// false and the late completion won't pause something we can't resume.
    private var wantsPause = false

    init() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            log.info("MediaRemote unavailable; media pause disabled")
            sendCommand = nil
            getIsPlaying = nil
            return
        }
        sendCommand = dlsym(handle, "MRMediaRemoteSendCommand").map {
            unsafeBitCast($0, to: SendCommand.self)
        }
        getIsPlaying = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying").map {
            unsafeBitCast($0, to: GetIsPlaying.self)
        }
        if sendCommand == nil || getIsPlaying == nil {
            log.info("MediaRemote symbols missing; media pause disabled")
        }
    }

    /// Pauses playback if something is currently playing. No-op otherwise.
    func pauseIfPlaying() {
        guard let getIsPlaying, let sendCommand else { return }
        wantsPause = true
        getIsPlaying(.main) { [weak self] isPlaying in
            guard let self, self.wantsPause, isPlaying, !self.didPause else { return }
            if sendCommand(self.cmdPause, nil) {
                self.didPause = true
                log.info("paused media for recording")
            }
        }
    }

    /// Resumes playback only if we paused it.
    func resumeIfPaused() {
        wantsPause = false
        guard didPause, let sendCommand else { return }
        didPause = false
        _ = sendCommand(cmdPlay, nil)
        log.info("resumed media after recording")
    }
}
