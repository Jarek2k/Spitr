//
//  LogStore.swift
//  Spitr
//
//  Persists Spitr's own os.Logger output to a rotating file under
//  ~/Library/Logs/Spitr, so a multi-day session can be inspected after the
//  fact (recognition misses, errors, slow memory growth) without keeping
//  Console.app open the whole time.
//
//  It reads only *this process's* unified-log entries (OSLogStore, current
//  process scope) and appends new ones on a timer — so every existing Logger
//  call site is captured automatically, with no extra logging code elsewhere
//  and with the privacy annotations intact. The app never logs transcript text
//  (only lengths/timings), so the file stays privacy-safe; the optional verbose
//  mode only adds periodic memory/thread samples, never content.
//

import Foundation
import OSLog
import Darwin

final class LogStore: @unchecked Sendable {
    static let shared = LogStore()

    /// Only Spitr's own subsystems are exported; third-party noise is skipped.
    private static let subsystems: Set<String> = ["com.jarek.Spitr", "com.spitr.app"]

    private let directoryURL: URL
    private let currentURL: URL
    /// Rotate the active file once it would exceed ~1 MB, keeping a handful of
    /// archives so a long session never grows the folder without bound.
    private let maxBytes = 1_000_000
    private let maxArchives = 5

    /// All file and bookkeeping work happens here, off the main thread.
    private let queue = DispatchQueue(label: "com.jarek.Spitr.logstore", qos: .utility)
    /// Only entries strictly after this are appended, so timer ticks don't dupe.
    private var lastExport = Date.distantPast
    private var flushTimer: DispatchSourceTimer?
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
        // shared Mac other local users have no business reading them.
        try? FileManager.default.createDirectory(
            at: directoryURL, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
    }

    /// The folder that holds the log files (for "open in Finder").
    var folder: URL { directoryURL }

    // MARK: - Lifecycle

    /// Begins periodic export. `verbose` additionally samples memory/threads
    /// every 60 s so a long session has a resource curve to inspect for leaks.
    func start(verbose: Bool) {
        queue.async {
            self.append(meta: "session start — Spitr \(Self.appVersion())")
            self.startFlushTimer()
            self.setResourceSampling(verbose)
        }
    }

    /// Toggle the resource sampler live when the Settings switch changes.
    func setVerbose(_ verbose: Bool) {
        queue.async { self.setResourceSampling(verbose) }
    }

    /// Export anything still buffered (e.g. before revealing the file).
    func flush() {
        queue.async { self.exportNewEntries() }
    }

    /// Final synchronous flush on quit so the last interval isn't lost.
    func stop() {
        queue.sync {
            self.exportNewEntries()
            self.append(meta: "session end")
        }
    }

    // MARK: - Timers

    private func startFlushTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 20)
        timer.setEventHandler { [weak self] in self?.exportNewEntries() }
        timer.resume()
        flushTimer = timer
    }

    private func setResourceSampling(_ on: Bool) {
        resourceTimer?.cancel()
        resourceTimer = nil
        guard on else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 60, repeating: 60)
        timer.setEventHandler { [weak self] in self?.sampleResources() }
        timer.resume()
        resourceTimer = timer
    }

    // MARK: - Export

    /// Pulls new entries for our subsystems out of the unified log and appends
    /// them. Runs only on `queue`.
    private func exportNewEntries() {
        guard let store = try? OSLogStore(scope: .currentProcessIdentifier) else { return }
        let position = store.position(date: lastExport)
        guard let entries = try? store.getEntries(at: position) else { return }

        var batch = ""
        var newest = lastExport
        for case let entry as OSLogEntryLog in entries {
            guard entry.date > lastExport, Self.subsystems.contains(entry.subsystem) else { continue }
            batch += Self.format(entry)
            if entry.date > newest { newest = entry.date }
        }
        lastExport = newest
        if !batch.isEmpty { write(batch) }
    }

    private static func format(_ entry: OSLogEntryLog) -> String {
        "\(stamp.string(from: entry.date)) \(symbol(entry.level)) [\(entry.category)] \(entry.composedMessage)\n"
    }

    private static func symbol(_ level: OSLogEntryLog.Level) -> String {
        switch level {
        case .debug:     return "DBG"
        case .info:      return "INF"
        case .notice:    return "NOT"
        case .error:     return "ERR"
        case .fault:     return "FLT"
        case .undefined: return "—"
        @unknown default: return "—"
        }
    }

    /// Writes a session/resource marker line (not from the unified log).
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
