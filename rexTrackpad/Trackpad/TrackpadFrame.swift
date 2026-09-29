import Foundation

/// One snapshot of every contact on a trackpad, as delivered by a `TrackpadInputProvider`.
struct TrackpadFrame: Sendable {
    /// Monotonic timestamp in seconds. Only differences between frames are meaningful.
    let timestamp: TimeInterval

    /// Identifies the physical device (built-in trackpad, Magic Trackpad, …).
    let deviceID: Int

    /// All reported touches, including hovering / lifting ones.
    let touches: [TouchPoint]

    /// Touches that are physically on the surface.
    var contacts: [TouchPoint] {
        touches.filter(\.isInContact)
    }
}
