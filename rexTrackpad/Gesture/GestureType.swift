import CoreGraphics
import Foundation

enum SwipeDirection: String, Codable, CaseIterable, Sendable {
    case left
    case right
    case up
    case down

    var displayName: String {
        switch self {
        case .left: return String(localized: "Left")
        case .right: return String(localized: "Right")
        case .up: return String(localized: "Up")
        case .down: return String(localized: "Down")
        }
    }

    /// Unit vector in trackpad space (y points away from the user).
    var unitVector: CGVector {
        switch self {
        case .left: return CGVector(dx: -1, dy: 0)
        case .right: return CGVector(dx: 1, dy: 0)
        case .up: return CGVector(dx: 0, dy: 1)
        case .down: return CGVector(dx: 0, dy: -1)
        }
    }
}

/// A physical gesture performed on the trackpad.
///
/// Gestures say nothing about *what* happens; that is `GestureAction`, and the
/// connection between the two is `GestureMapping`.
///
/// The enum is parameterised by finger count so 5-finger variants need no new cases.
/// Future kinds (not recognised in v0.1) would be added as new cases, e.g.
/// `.doubleTap(fingers:)`, `.longPress(fingers:)`, `.pinch(fingers:direction:)`,
/// `.rotate(direction:)`, `.cornerTap(corner:)`, `.chord(...)`.
enum TrackpadGesture: Hashable, Sendable {
    case tap(fingers: Int)
    case swipe(fingers: Int, direction: SwipeDirection)

    static let threeFingerTap = TrackpadGesture.tap(fingers: 3)
    static let fourFingerTap = TrackpadGesture.tap(fingers: 4)

    static let threeFingerSwipeLeft = TrackpadGesture.swipe(fingers: 3, direction: .left)
    static let threeFingerSwipeRight = TrackpadGesture.swipe(fingers: 3, direction: .right)
    static let threeFingerSwipeUp = TrackpadGesture.swipe(fingers: 3, direction: .up)
    static let threeFingerSwipeDown = TrackpadGesture.swipe(fingers: 3, direction: .down)

    static let fourFingerSwipeLeft = TrackpadGesture.swipe(fingers: 4, direction: .left)
    static let fourFingerSwipeRight = TrackpadGesture.swipe(fingers: 4, direction: .right)

    /// Gestures offered in the menu, in display order.
    static let configurable: [TrackpadGesture] = [
        .threeFingerTap,
        .fourFingerTap,
        .threeFingerSwipeLeft,
        .threeFingerSwipeRight,
        .threeFingerSwipeUp,
        .threeFingerSwipeDown,
        .fourFingerSwipeLeft,
        .fourFingerSwipeRight,
    ]

    var fingerCount: Int {
        switch self {
        case .tap(let fingers), .swipe(let fingers, _):
            return fingers
        }
    }

    /// Stable string used for persistence, e.g. `tap.3`, `swipe.4.left`.
    var identifier: String {
        switch self {
        case .tap(let fingers):
            return "tap.\(fingers)"
        case .swipe(let fingers, let direction):
            return "swipe.\(fingers).\(direction.rawValue)"
        }
    }

    init?(identifier: String) {
        let parts = identifier.split(separator: ".").map(String.init)
        guard parts.count >= 2, let fingers = Int(parts[1]), (1...10).contains(fingers) else { return nil }
        switch (parts[0], parts.count) {
        case ("tap", 2):
            self = .tap(fingers: fingers)
        case ("swipe", 3):
            guard let direction = SwipeDirection(rawValue: parts[2]) else { return nil }
            self = .swipe(fingers: fingers, direction: direction)
        default:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .tap(let fingers):
            return String(localized: "\(fingers)-Finger Tap")
        case .swipe(let fingers, let direction):
            return String(localized: "\(fingers)-Finger Swipe \(direction.displayName)")
        }
    }
}

extension TrackpadGesture: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        guard let gesture = TrackpadGesture(identifier: identifier) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown gesture '\(identifier)'")
        }
        self = gesture
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(identifier)
    }
}
