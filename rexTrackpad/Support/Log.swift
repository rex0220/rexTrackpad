import Foundation
import os

/// Centralised loggers. View them with Console.app or:
///
///     log stream --predicate 'subsystem == "com.rex0220.rexTrackpad"' --level debug
///
/// - `info` / `notice` / `error` messages are kept in all builds (they are cheap and low-volume).
/// - `Log.verbose(...)` is for high-frequency diagnostics (per-frame data, rejected gestures, …)
///   and is compiled out of Release builds entirely.
enum Log {
    static let subsystem = "com.rex0220.rexTrackpad"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let trackpad = Logger(subsystem: subsystem, category: "trackpad")
    static let gesture = Logger(subsystem: subsystem, category: "gesture")
    static let action = Logger(subsystem: subsystem, category: "action")
    static let browser = Logger(subsystem: subsystem, category: "browser")
    static let keyboard = Logger(subsystem: subsystem, category: "keyboard")
    static let permission = Logger(subsystem: subsystem, category: "permission")
    static let settings = Logger(subsystem: subsystem, category: "settings")

    /// Detailed diagnostics that only exist in Debug builds.
    @inline(__always)
    static func verbose(_ logger: Logger, _ message: @autoclosure () -> String) {
        #if DEBUG
        let text = message()
        logger.debug("\(text, privacy: .public)")
        #endif
    }
}
