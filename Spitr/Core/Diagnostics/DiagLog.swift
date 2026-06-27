//
//  DiagLog.swift
//  Spitr
//
//  Lightweight logging facade used everywhere instead of a bare os.Logger.
//  Each call does two cheap things: mirror the line to os.Logger (so Console.app
//  and `log stream` still work) and hand the same line to LogStore for the
//  on-disk file. There is no unified-log polling — writes happen only when
//  something is actually logged, so an idle app does no logging work at all.
//
//  Every message is public: Spitr only ever logs events, timings and counts,
//  never dictated text, so call sites pass plain interpolated strings without
//  per-argument privacy annotations. Marking the whole message `.public` does
//  mean it stays readable in the unified log (Console / sysdiagnose) rather than
//  being redacted to <private> — that's acceptable here precisely because the
//  hard rule "never log content" already guarantees nothing sensitive is passed.
//

import os

struct DiagLog {
    private let logger: Logger
    private let category: String

    init(category: String, subsystem: String = "com.jarek.Spitr") {
        self.logger = Logger(subsystem: subsystem, category: category)
        self.category = category
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        LogStore.shared.record(category: category, symbol: "INF", message: message)
    }

    func notice(_ message: String) {
        logger.notice("\(message, privacy: .public)")
        LogStore.shared.record(category: category, symbol: "NOT", message: message)
    }

    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
        LogStore.shared.record(category: category, symbol: "WRN", message: message)
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        LogStore.shared.record(category: category, symbol: "ERR", message: message)
    }

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        LogStore.shared.record(category: category, symbol: "DBG", message: message)
    }
}
