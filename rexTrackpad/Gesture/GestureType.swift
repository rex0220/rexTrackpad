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

/// Area of the trackpad a tap landed on, judged by the centre of the fingers. The
/// surface is split into a 3 × 3 grid; the middle cell is a plain `.tap`.
enum TapZone: String, Codable, CaseIterable, Sendable {
    case left
    case right
    case top
    case bottom
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var displayName: String {
        switch self {
        case .left: return String(localized: "Left side")
        case .right: return String(localized: "Right side")
        case .top: return String(localized: "Top edge")
        case .bottom: return String(localized: "Bottom edge")
        case .topLeft: return String(localized: "Top-left corner")
        case .topRight: return String(localized: "Top-right corner")
        case .bottomLeft: return String(localized: "Bottom-left corner")
        case .bottomRight: return String(localized: "Bottom-right corner")
        }
    }

    /// The zone whose binding a corner uses when it has none of its own: its left /
    /// right side, so bindings made before corners existed keep covering them.
    var fallback: TapZone? {
        switch self {
        case .topLeft, .bottomLeft: return .left
        case .topRight, .bottomRight: return .right
        case .left, .right, .top, .bottom: return nil
        }
    }

    /// The zone at a column (-1 left, 0 middle, 1 right) and row (-1 bottom, 0 middle,
    /// 1 top), or nil for the middle cell.
    init?(column: Int, row: Int) {
        switch (column, row) {
        case (-1, 1): self = .topLeft
        case (0, 1): self = .top
        case (1, 1): self = .topRight
        case (-1, 0): self = .left
        case (1, 0): self = .right
        case (-1, -1): self = .bottomLeft
        case (0, -1): self = .bottom
        case (1, -1): self = .bottomRight
        default: return nil
        }
    }
}

/// Which way a circle was drawn.
enum CircleDirection: String, Codable, CaseIterable, Sendable {
    case clockwise
    case counterClockwise

    var displayName: String {
        switch self {
        case .clockwise: return String(localized: "Clockwise")
        case .counterClockwise: return String(localized: "Counter-clockwise")
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
    /// A tap near an edge or corner of the trackpad. Taps in the middle are plain
    /// `.tap`, and a zone tap without its own binding behaves like its fallback
    /// (corner → side → plain `.tap`).
    case zoneTap(fingers: Int, zone: TapZone)
    case swipe(fingers: Int, direction: SwipeDirection)
    /// A circle drawn with the fingers, judged when they lift.
    case circle(fingers: Int, direction: CircleDirection)

    static let threeFingerTap = TrackpadGesture.tap(fingers: 3)
    static let threeFingerTapLeft = TrackpadGesture.zoneTap(fingers: 3, zone: .left)
    static let threeFingerTapRight = TrackpadGesture.zoneTap(fingers: 3, zone: .right)
    static let threeFingerTapTop = TrackpadGesture.zoneTap(fingers: 3, zone: .top)
    static let threeFingerTapBottom = TrackpadGesture.zoneTap(fingers: 3, zone: .bottom)
    static let threeFingerTapTopLeft = TrackpadGesture.zoneTap(fingers: 3, zone: .topLeft)
    static let threeFingerTapTopRight = TrackpadGesture.zoneTap(fingers: 3, zone: .topRight)
    static let threeFingerTapBottomLeft = TrackpadGesture.zoneTap(fingers: 3, zone: .bottomLeft)
    static let threeFingerTapBottomRight = TrackpadGesture.zoneTap(fingers: 3, zone: .bottomRight)
    static let fourFingerTap = TrackpadGesture.tap(fingers: 4)

    static let threeFingerSwipeLeft = TrackpadGesture.swipe(fingers: 3, direction: .left)
    static let threeFingerSwipeRight = TrackpadGesture.swipe(fingers: 3, direction: .right)
    static let threeFingerSwipeUp = TrackpadGesture.swipe(fingers: 3, direction: .up)
    static let threeFingerSwipeDown = TrackpadGesture.swipe(fingers: 3, direction: .down)

    static let fourFingerSwipeLeft = TrackpadGesture.swipe(fingers: 4, direction: .left)
    static let fourFingerSwipeRight = TrackpadGesture.swipe(fingers: 4, direction: .right)

    static let oneFingerCircleClockwise = TrackpadGesture.circle(fingers: 1, direction: .clockwise)
    static let oneFingerCircleCounterClockwise = TrackpadGesture.circle(fingers: 1, direction: .counterClockwise)
    static let threeFingerCircleClockwise = TrackpadGesture.circle(fingers: 3, direction: .clockwise)
    static let threeFingerCircleCounterClockwise = TrackpadGesture.circle(fingers: 3, direction: .counterClockwise)

    /// Three-finger taps laid out as on the trackpad, top row first.
    static let threeFingerTapGrid: [[TrackpadGesture]] = [
        [.threeFingerTapTopLeft, .threeFingerTapTop, .threeFingerTapTopRight],
        [.threeFingerTapLeft, .threeFingerTap, .threeFingerTapRight],
        [.threeFingerTapBottomLeft, .threeFingerTapBottom, .threeFingerTapBottomRight],
    ]

    /// Gestures offered in the settings, in display order (the three-finger taps are
    /// shown as `threeFingerTapGrid`).
    static let configurable: [TrackpadGesture] = threeFingerTapGrid.flatMap { $0 } + [
        .oneFingerCircleClockwise,
        .oneFingerCircleCounterClockwise,
        .fourFingerTap,
        .threeFingerSwipeLeft,
        .threeFingerSwipeRight,
        .threeFingerSwipeUp,
        .threeFingerSwipeDown,
        .fourFingerSwipeLeft,
        .fourFingerSwipeRight,
        .threeFingerCircleClockwise,
        .threeFingerCircleCounterClockwise,
    ]

    var fingerCount: Int {
        switch self {
        case .tap(let fingers), .zoneTap(let fingers, _), .swipe(let fingers, _), .circle(let fingers, _):
            return fingers
        }
    }

    /// The gesture whose binding applies when this one has none of its own.
    var fallback: TrackpadGesture? {
        if case .zoneTap(let fingers, let zone) = self {
            return zone.fallback.map { .zoneTap(fingers: fingers, zone: $0) } ?? .tap(fingers: fingers)
        }
        return nil
    }

    /// Stable string used for persistence, e.g. `tap.3`, `tap.3.left`, `swipe.4.left`.
    var identifier: String {
        switch self {
        case .tap(let fingers):
            return "tap.\(fingers)"
        case .zoneTap(let fingers, let zone):
            return "tap.\(fingers).\(zone.rawValue)"
        case .swipe(let fingers, let direction):
            return "swipe.\(fingers).\(direction.rawValue)"
        case .circle(let fingers, let direction):
            return "circle.\(fingers).\(direction.rawValue)"
        }
    }

    init?(identifier: String) {
        let parts = identifier.split(separator: ".").map(String.init)
        guard parts.count >= 2, let fingers = Int(parts[1]), (1...10).contains(fingers) else { return nil }
        switch (parts[0], parts.count) {
        case ("tap", 2):
            self = .tap(fingers: fingers)
        case ("tap", 3):
            guard let zone = TapZone(rawValue: parts[2]) else { return nil }
            self = .zoneTap(fingers: fingers, zone: zone)
        case ("swipe", 3):
            guard let direction = SwipeDirection(rawValue: parts[2]) else { return nil }
            self = .swipe(fingers: fingers, direction: direction)
        case ("circle", 3):
            guard let direction = CircleDirection(rawValue: parts[2]) else { return nil }
            self = .circle(fingers: fingers, direction: direction)
        default:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .tap(let fingers):
            return String(localized: "\(fingers)-Finger Tap")
        case .zoneTap(let fingers, let zone):
            return String(localized: "\(fingers)-Finger Tap (\(zone.displayName))")
        case .swipe(let fingers, let direction):
            return String(localized: "\(fingers)-Finger Swipe \(direction.displayName)")
        case .circle(let fingers, let direction):
            return String(localized: "\(fingers)-Finger Circle (\(direction.displayName))")
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
