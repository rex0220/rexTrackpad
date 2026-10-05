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
    /// Taps whose finger centre is within this fraction of the width from the left /
    /// right edge are zone taps (left / right side, or a corner).
    var tapZoneEdge: Double = 0.35
    /// The same for the top / bottom edge, as a fraction of the height.
    var tapZoneEdgeVertical: Double = 0.30

    // MARK: Swipe

    /// The finger count must be unchanged this long before a swipe anchor is taken.
    var settleTime: TimeInterval = 0.03
    /// Average finger travel required.
    var swipeMinimumDistance: Double = 0.12
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

    // MARK: Circle

    /// The fingers' centre must turn at least this far around the circle (degrees).
    var circleMinimumTurn: Double = 300
    /// Average radius required (trackpad heights). Smaller loops — and the jitter of a
    /// lifting finger, typically below 0.02 — are ignored.
    var circleMinimumRadius: Double = 0.06
    /// Largest allowed spread of the radius (standard deviation / mean). Rejects ovals
    /// that are too flat and zig-zags.
    var circleMaximumRadiusVariation: Double = 0.35
    /// How consistently the path must turn one way (net turn / total turn).
    var circleDirectionConsistency: Double = 0.90
    var circleMinimumDuration: TimeInterval = 0.25
    /// Hand-drawn circles take about 0.6–0.8 s; slow, elongated loops are pointing.
    var circleMaximumDuration: TimeInterval = 1.5
    /// One-finger circles move the pointer like ordinary pointing, so they must turn
    /// almost all the way round to count.
    var singleFingerCircleMinimumTurn: Double = 330

    // MARK: Safety

    /// After a gesture fires, sessions starting within this time are ignored.
    var cooldown: TimeInterval = 0.35
    /// A session with no frames for this long is discarded (missed lift frame).
    var staleSessionTimeout: TimeInterval = 1.0

    // MARK: Geometry

    /// Width / height of the trackpad surface.
    var aspectRatio: Double = 1.6

    static let `default` = GestureConfiguration()

    /// The zone of the 3 × 3 tap grid containing `point` (normalised, y = 0 at the
    /// bottom), or nil for the middle cell.
    func tapZone(at point: CGPoint) -> TapZone? {
        func band(_ value: Double, edge: Double) -> Int {
            value < edge ? -1 : (value > 1 - edge ? 1 : 0)
        }
        return TapZone(column: band(Double(point.x), edge: tapZoneEdge),
                       row: band(Double(point.y), edge: tapZoneEdgeVertical))
    }
}

extension GestureConfiguration: Codable {
    private enum CodingKeys: String, CodingKey {
        case minimumFingers, maximumFingers
        case tapMaximumDuration, tapMaximumMovement, tapMaximumLandingSpread, tapZoneEdge, tapZoneEdgeVertical
        case settleTime, swipeMinimumDistance, swipeMaximumDuration, swipeMinimumVelocity
        case swipeDirectionRatio, swipeFingerAgreement
        case circleMinimumTurn, circleMinimumRadius, circleMaximumRadiusVariation
        case circleDirectionConsistency, circleMinimumDuration, circleMaximumDuration
        case singleFingerCircleMinimumTurn
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
        try decode(\.tapZoneEdge, .tapZoneEdge)
        try decode(\.tapZoneEdgeVertical, .tapZoneEdgeVertical)
        try decode(\.settleTime, .settleTime)
        try decode(\.swipeMinimumDistance, .swipeMinimumDistance)
        try decode(\.swipeMaximumDuration, .swipeMaximumDuration)
        try decode(\.swipeMinimumVelocity, .swipeMinimumVelocity)
        try decode(\.swipeDirectionRatio, .swipeDirectionRatio)
        try decode(\.swipeFingerAgreement, .swipeFingerAgreement)
        try decode(\.circleMinimumTurn, .circleMinimumTurn)
        try decode(\.circleMinimumRadius, .circleMinimumRadius)
        try decode(\.circleMaximumRadiusVariation, .circleMaximumRadiusVariation)
        try decode(\.circleDirectionConsistency, .circleDirectionConsistency)
        try decode(\.circleMinimumDuration, .circleMinimumDuration)
        try decode(\.circleMaximumDuration, .circleMaximumDuration)
        try decode(\.singleFingerCircleMinimumTurn, .singleFingerCircleMinimumTurn)
        try decode(\.cooldown, .cooldown)
        try decode(\.staleSessionTimeout, .staleSessionTimeout)
        try decode(\.aspectRatio, .aspectRatio)

        self = value
    }
}
