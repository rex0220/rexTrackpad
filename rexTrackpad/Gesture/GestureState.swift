import Foundation

/// Lifecycle of one touch session (first finger down → all fingers up).
///
///     idle ──finger down──▶ tracking ──recognized / rejected──▶ waitingForRelease
///      ▲                       │                                     │
///      └──────all fingers up───┴─────────────all fingers up──────────┘
///
/// A session can fire at most one gesture: once it leaves `tracking`
/// nothing else is recognized until every finger has been lifted.
enum GestureState: Equatable {
    case idle
    case tracking
    case waitingForRelease
}

/// Why a session did not produce a gesture. Used for logging and tests.
enum GestureRejection: Equatable {
    case unsupportedFingerCount(Int)
    case tapTooLong
    case tapMoved
    case buttonPressed
    case swipeTooSlow
    case swipeDiagonal
    case swipeFingersDisagree
    case cooldown
    case staleSession
}
