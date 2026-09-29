import Foundation

/// Lifecycle state of a trackpad input source.
enum TrackpadInputState: Equatable, Sendable {
    case stopped
    case running(deviceCount: Int)
    case unavailable(reason: String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .stopped:
            return String(localized: "Stopped")
        case .running(let count):
            return count == 1 ? String(localized: "Monitoring 1 device") : String(localized: "Monitoring \(count) devices")
        case .unavailable(let reason):
            return String(localized: "Unavailable: \(reason)")
        }
    }
}

/// Source of raw trackpad frames.
///
/// The rest of the app only talks to this protocol. The current implementation
/// (`MultitouchTrackpadProvider`) uses a private framework; if Apple ever ships a
/// public equivalent, only a new conforming type needs to be written.
protocol TrackpadInputProvider: AnyObject {
    /// Called for every frame. **May be invoked on an arbitrary background thread.**
    /// Set it before calling `start()`.
    var onFrame: ((TrackpadFrame) -> Void)? { get set }

    /// Called on the main thread when `state` changes.
    var onStateChange: ((TrackpadInputState) -> Void)? { get set }

    var state: TrackpadInputState { get }

    /// Number of frames received since launch (diagnostics only).
    var framesReceived: UInt64 { get }

    /// Starts observing. Must be called on the main thread. Never throws or crashes
    /// when the source is unavailable; `state` becomes `.unavailable` instead.
    func start()

    /// Stops observing. Must be called on the main thread.
    func stop()
}
