import Foundation

/// Lifecycle of one touch session (first finger down → every finger up).
///
///     idle ──finger down──▶ tracking ──▶ recognized ────────┐
///      ▲                       │                            ├──all fingers up──▶ idle
///      │                       └──────▶ waitingForRelease ──┘
///      └──────────────all fingers up (tap evaluated)──────────
///
/// A session fires at most one gesture: once it leaves `tracking`, nothing else is
/// recognised until every finger has been lifted.
enum GestureState: Equatable, Sendable {
    case idle
    case tracking
    /// A gesture fired; waiting for the fingers to lift.
    case recognized(TrackpadGesture)
    /// Rejected or debounced; waiting for the fingers to lift.
    case waitingForRelease

    var displayName: String {
        switch self {
        case .idle: return "idle"
        case .tracking: return "tracking"
        case .recognized(let gesture): return "recognized (\(gesture.displayName))"
        case .waitingForRelease: return "waiting for release"
        }
    }
}

/// Why a session did not produce a gesture (logged in Debug builds).
enum GestureRejection: Equatable, Sendable {
    case tooManyFingers
    case physicalClick
    case fingersReplaced
    case fingersLandedApart
    case tapTooLong
    case tapMoved
    case diagonalSwipe
    case swipeTooSlow
    case inconsistentFingers

    var displayName: String {
        switch self {
        case .tooManyFingers: return "too many fingers"
        case .physicalClick: return "physical click"
        case .fingersReplaced: return "fingers replaced during session"
        case .fingersLandedApart: return "fingers landed too far apart in time"
        case .tapTooLong: return "tap too long"
        case .tapMoved: return "fingers moved during tap"
        case .diagonalSwipe: return "diagonal swipe"
        case .swipeTooSlow: return "swipe too slow"
        case .inconsistentFingers: return "fingers moved in different directions"
        }
    }
}
