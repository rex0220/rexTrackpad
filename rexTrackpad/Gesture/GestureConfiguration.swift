import Foundation

/// Thresholds used by `GestureRecognizer`.
///
/// Positions are normalised trackpad coordinates. Distances are measured in
/// trackpad-*height* units: x is multiplied by `aspectRatio` first, so the same
/// physical movement counts the same horizontally and vertically.
/// Durations are in seconds, velocities in units per second.
///
/// Stored in UserDefaults as JSON. Missing keys fall back to the defaults, so new
/// thresholds can be added without breaking saved settings.
struct GestureConfiguration: Equatable, Sendable {
    // MARK: Finger counts

    /// Fewer fingers are ordinary pointing / scrolling and are ignored silently.
    var minimumFingers = 3
    /// More fingers (a resting palm, …) reject the session.
    var maximumFingers = 5

    // MARK: Tap

    /// First finger down → last finger up.
    var tapMaximumDuration: TimeInterval = 0.35
    /// No single finger may move further than this.
    var tapMaximumMovement: Double = 0.05
    /// All fingers must land within this time of each other.
    var tapMaximumLandingSpread: TimeInterval = 0.15

    // MARK: Swipe

    /// The finger count must be unchanged this long before a swipe anchor is taken.
    var settleTime: TimeInterval = 0.03
    /// Average finger travel required.
    var swipeMinimumDistance: Double = 0.20
    /// `swipeMinimumDistance` must be covered within this window (slow drags never count).
    var swipeMaximumDuration: TimeInterval = 0.60
    /// Average speed required.
    var swipeMinimumVelocity: Double = 0.4
    /// The dominant axis must be this many times larger than the other one
    /// (2.0 ≈ within 26.6° of the axis). Rejects diagonal movement.
    var swipeDirectionRatio: Double = 2.0
    /// Every finger must travel at least this fraction of the average distance
    /// in the swipe direction. Rejects pinches and rotations.
    var swipeFingerAgreement: Double = 0.5

    // MARK: Safety

    /// After a gesture fires, sessions starting within this time are ignored.
    var cooldown: TimeInterval = 0.35
    /// A session with no frames for this long is discarded (missed lift frame).
    var staleSessionTimeout: TimeInterval = 1.0

    // MARK: Geometry

    /// Width / height of the trackpad surface.
    var aspectRatio: Double = 1.6

    static let `default` = GestureConfiguration()
}

extension GestureConfiguration: Codable {
    private enum CodingKeys: String, CodingKey {
        case minimumFingers, maximumFingers
        case tapMaximumDuration, tapMaximumMovement, tapMaximumLandingSpread
        case settleTime, swipeMinimumDistance, swipeMaximumDuration, swipeMinimumVelocity
        case swipeDirectionRatio, swipeFingerAgreement
        case cooldown, staleSessionTimeout
        case aspectRatio
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var value = GestureConfiguration()

        func decode<T: Decodable>(_ keyPath: WritableKeyPath<GestureConfiguration, T>, _ key: CodingKeys) throws {
            if let decoded = try container.decodeIfPresent(T.self, forKey: key) {
                value[keyPath: keyPath] = decoded
            }
        }

        try decode(\.minimumFingers, .minimumFingers)
        try decode(\.maximumFingers, .maximumFingers)
        try decode(\.tapMaximumDuration, .tapMaximumDuration)
        try decode(\.tapMaximumMovement, .tapMaximumMovement)
        try decode(\.tapMaximumLandingSpread, .tapMaximumLandingSpread)
        try decode(\.settleTime, .settleTime)
        try decode(\.swipeMinimumDistance, .swipeMinimumDistance)
        try decode(\.swipeMaximumDuration, .swipeMaximumDuration)
        try decode(\.swipeMinimumVelocity, .swipeMinimumVelocity)
        try decode(\.swipeDirectionRatio, .swipeDirectionRatio)
        try decode(\.swipeFingerAgreement, .swipeFingerAgreement)
        try decode(\.cooldown, .cooldown)
        try decode(\.staleSessionTimeout, .staleSessionTimeout)
        try decode(\.aspectRatio, .aspectRatio)

        self = value
    }
}
