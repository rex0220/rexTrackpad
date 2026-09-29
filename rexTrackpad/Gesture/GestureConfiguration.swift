import Foundation

/// Thresholds used by `GestureRecognizer`.
///
/// Distances are in normalized trackpad units (the full width/height is 1.0),
/// durations in seconds, velocities in units per second.
struct GestureConfiguration: Equatable {
    // MARK: Tap
    /// First finger down → last finger up must be shorter than this.
    var tapMaximumDuration: TimeInterval = 0.30
    /// No finger may travel further than this during a tap.
    var tapMaximumMovement: Double = 0.04

    // MARK: Swipe
    /// Distance the fingers' centroid must travel.
    var swipeMinimumDistance: Double = 0.12
    /// Time allowed from "all fingers down" until `swipeMinimumDistance` is reached.
    var swipeMaximumDuration: TimeInterval = 0.60
    /// Average centroid speed required; rejects slow drags / resting hands.
    var swipeMinimumVelocity: Double = 0.25
    /// The dominant axis must be at least this many times larger than the other axis.
    /// 2.0 accepts about ±26° around the axis and rejects diagonals.
    var swipeDirectionRatio: Double = 2.0
    /// Every finger must travel at least this fraction of the centroid distance in the
    /// swipe direction. Rejects pinches / rotations whose centroid happens to drift.
    var swipeFingerAgreement: Double = 0.5

    // MARK: Safety
    /// After a gesture fires, new gestures are ignored for this long.
    var cooldown: TimeInterval = 0.35
    /// If no frame arrives for this long, the current session is discarded
    /// (protects against a missed "all fingers lifted" frame).
    var staleFrameTimeout: TimeInterval = 0.50

    /// Only these finger counts produce gestures.
    var supportedFingerCounts: ClosedRange<Int> = 3...4

    static let `default` = GestureConfiguration()
}
