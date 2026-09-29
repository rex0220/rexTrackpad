import Foundation

enum SwipeDirection: String, CaseIterable {
    case left, right, up, down
}

/// A recognized trackpad gesture. Independent of what it triggers (see `GestureMapping`).
///
/// Raw values are persisted in UserDefaults, so do not rename existing cases.
enum TrackpadGesture: String, CaseIterable, Hashable {
    case threeFingerTap
    case fourFingerTap

    case threeFingerSwipeLeft
    case threeFingerSwipeRight
    case threeFingerSwipeUp
    case threeFingerSwipeDown

    case fourFingerSwipeLeft
    case fourFingerSwipeRight
    case fourFingerSwipeUp
    case fourFingerSwipeDown

    static func tap(fingers: Int) -> TrackpadGesture? {
        switch fingers {
        case 3: return .threeFingerTap
        case 4: return .fourFingerTap
        default: return nil
        }
    }

    static func swipe(fingers: Int, direction: SwipeDirection) -> TrackpadGesture? {
        switch (fingers, direction) {
        case (3, .left): return .threeFingerSwipeLeft
        case (3, .right): return .threeFingerSwipeRight
        case (3, .up): return .threeFingerSwipeUp
        case (3, .down): return .threeFingerSwipeDown
        case (4, .left): return .fourFingerSwipeLeft
        case (4, .right): return .fourFingerSwipeRight
        case (4, .up): return .fourFingerSwipeUp
        case (4, .down): return .fourFingerSwipeDown
        default: return nil
        }
    }

    var fingerCount: Int {
        switch self {
        case .threeFingerTap, .threeFingerSwipeLeft, .threeFingerSwipeRight, .threeFingerSwipeUp, .threeFingerSwipeDown:
            return 3
        case .fourFingerTap, .fourFingerSwipeLeft, .fourFingerSwipeRight, .fourFingerSwipeUp, .fourFingerSwipeDown:
            return 4
        }
    }

    var swipeDirection: SwipeDirection? {
        switch self {
        case .threeFingerTap, .fourFingerTap: return nil
        case .threeFingerSwipeLeft, .fourFingerSwipeLeft: return .left
        case .threeFingerSwipeRight, .fourFingerSwipeRight: return .right
        case .threeFingerSwipeUp, .fourFingerSwipeUp: return .up
        case .threeFingerSwipeDown, .fourFingerSwipeDown: return .down
        }
    }

    var displayName: String {
        let fingers = "\(fingerCount)-finger"
        guard let direction = swipeDirection else { return "\(fingers) tap" }
        return "\(fingers) swipe \(direction.rawValue)"
    }
}
