//
//  LogStore.swift
//  Spitr
//
//  Persists Spitr's own log output to a rotating file under ~/Library/Logs/Spitr,
//  so a multi-day session can be inspected after the fact (recognition misses,
//  errors, slow memory growth) without keeping Console.app open the whole time.
//
//  Lines are written event-driven: every DiagLog call hands its already-formatted
//  message straight to `record(...)`, which appends it on a background queue. An
//  idle app does no logging work — there is no timer scanning the unified log.
//  The app never logs transcript text (only lengths/timings), so the file stays
//  privacy-safe; the optional verbose mode only adds periodic memory/thread
//  samples, never content.
//

import Foundation
import Darwin

final class LogStore: @unchecked Sendable {
    static let shared = LogStore()

    private let directoryURL: URL
    private let currentURL: URL
    /// Rotate the active file once it would exceed ~1 MB, keeping a handful of
    /// archives so a long session never grows the folder without bound.
    private let maxBytes = 1_000_000
    private let maxArchives = 5

    /// All file and bookkeeping work happens here, off the main thread. Serial,
    /// so the ISO8601 formatter and the file handle are only ever touched here.
    private let queue = DispatchQueue(label: "com.jarek.Spitr.logstore", qos: .utility)
    private var resourceTimer: DispatchSourceTimer?

    private static let stamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library")
        directoryURL = base.appendingPathComponent("Logs/Spitr", isDirectory: true)
        currentURL = directoryURL.appendingPathComponent("spitr.log")
        // Owner-only: logs carry timings/device ids (never transcripts), but on a
        // shared Mac other local users have no business reading them. createDirectory
        // only applies the mode when it creates the folder, so enforce 0o700 again on
        // an already-existing one (e.g. left looser by an older build).
        let fm = FileManager.default
        try? fm.createDirectory(
            at: directoryURL, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
    }

    /// The folder that holds the log files (for "open in Finder").
    var folder: URL { directoryURL }

    // MARK: - Lifecycle

    /// Marks a new session. `verbose` additionally samples memory/threads every
    /// few minutes so a long session has a resource curve to inspect for leaks.
    func start(verbose: Bool) {
        queue.async {
            self.append(meta: "session start — Spitr \(Self.appVersion())")
            self.setResourceSampling(verbose)
        }
    }

    /// Toggle the resource sampler live when the Settings switch changes.
    func setVerbose(_ verbose: Bool) {
        queue.async { self.setResourceSampling(verbose) }
    }

    /// Barrier: returns once every queued write has hit disk (e.g. before
    /// revealing the file in Finder). Call from off `queue` only (main is fine) —
    /// invoking it from within the queue would deadlock.
    func flush() {
        queue.sync {}
    }

    /// Final flush on quit so the last lines aren't lost.
    func stop() {
        queue.sync { self.append(meta: "session end") }
    }

    // MARK: - Recording log lines (called by DiagLog)

    /// Appends one pre-formatted log line. The timestamp is captured now (call
    /// time), the formatting + write happen on the serial queue.
    func record(category: String, symbol: String, message: String) {
        let date = Date()
        queue.async {
            self.write("\(Self.stamp.string(from: date)) \(symbol) [\(category)] \(message)\n")
        }
    }

    /// Writes a session/resource marker line.
    private func append(meta: String) {
        write("\(Self.stamp.string(from: Date())) ─── \(meta) ───\n")
    }

    // MARK: - File writing & rotation

    private func write(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        rotateIfNeeded(adding: data.count)

        let fm = FileManager.default
        if !fm.fileExists(atPath: currentURL.path) {
            fm.createFile(atPath: currentURL.path, contents: nil,
                          attributes: [.posixPermissions: 0o600])
        }
        if let handle = try? FileHandle(forWritingTo: currentURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: currentURL)
        }
    }

    /// Shifts spitr.log → spitr.1.log → … → spitr.N.log, dropping the oldest,
    /// once the active file would cross the size cap.
    private func rotateIfNeeded(adding bytes: Int) {
        let attrs = try? FileManager.default.attributesOfItem(atPath: currentURL.path)
        let current = (attrs?[.size] as? Int) ?? 0
        guard current > 0, current + bytes > maxBytes else { return }

        let fm = FileManager.default
        try? fm.removeItem(at: archiveURL(maxArchives))
        var i = maxArchives - 1
        while i >= 1 {
            let from = archiveURL(i)
            if fm.fileExists(atPath: from.path) {
                try? fm.moveItem(at: from, to: archiveURL(i + 1))
            }
            i -= 1
        }
        try? fm.moveItem(at: currentURL, to: archiveURL(1))
    }

    private func archiveURL(_ n: Int) -> URL {
        directoryURL.appendingPathComponent("spitr.\(n).log")
    }

    // MARK: - Resource sampling

    private func setResourceSampling(_ on: Bool) {
        resourceTimer?.cancel()
        resourceTimer = nil
        guard on else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 300, repeating: 300)
        timer.setEventHandler { [weak self] in self?.sampleResources() }
        timer.resume()
        resourceTimer = timer
    }

    private func sampleResources() {
        let mem = ByteCountFormatter.string(fromByteCount: Int64(Self.residentBytes()), countStyle: .memory)
        append(meta: "resources mem=\(mem) threads=\(Self.threadCount())")
    }

    /// Resident memory of this process, the simplest leak signal over time.
    private static func residentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.stride / MemoryLayout<natural_t>.stride)
        let kr = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? info.resident_size : 0
    }

    /// Live thread count — a proxy for runaway async work (a Task that spawns
    /// threads but never finishes shows up here over a long session).
    private static func threadCount() -> Int {
        var list: thread_act_array_t?
        var count: mach_msg_type_number_t = 0
        guard task_threads(mach_task_self_, &list, &count) == KERN_SUCCESS, let list else { return 0 }
        let size = vm_size_t(Int(count) * MemoryLayout<thread_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: UnsafeMutableRawPointer(list))), size)
        return Int(count)
    }

    private static func appVersion() -> String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }
}
