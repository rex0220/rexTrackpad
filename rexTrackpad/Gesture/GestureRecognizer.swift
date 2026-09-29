import CoreGraphics
import Foundation

/// Measurements describing a (candidate) gesture.
struct GestureMetrics: Equatable, Sendable {
    var fingers: Int
    var duration: TimeInterval
    /// Average finger translation in trackpad-height units (x already scaled by the aspect ratio).
    var translation: CGVector
    /// Largest movement of a single finger since it landed.
    var maxFingerMovement: Double

    var distance: Double {
        hypot(Double(translation.dx), Double(translation.dy))
    }

    var velocity: Double {
        duration > 0 ? distance / duration : 0
    }

    var summary: String {
        String(format: "fingers=%d duration=%.3fs dx=%.3f dy=%.3f distance=%.3f velocity=%.2f/s maxMove=%.3f",
               fingers, duration, Double(translation.dx), Double(translation.dy), distance, velocity, maxFingerMovement)
    }
}

enum GestureRecognizerEvent: Sendable {
    /// A new contact session started.
    case began(fingers: Int)
    case recognized(TrackpadGesture, GestureMetrics)
    case rejected(GestureRejection, GestureMetrics)
    /// A session started too soon after the previous gesture and is ignored.
    case debounced(sinceLastGesture: TimeInterval)
}

/// Live view of the recognizer, used by the Debug Monitor.
struct GestureDiagnostics: Sendable {
    var timestamp: TimeInterval
    var deviceID: Int
    var state: GestureState
    var contacts: [TouchPoint]
    var maxFingers: Int
    var sessionDuration: TimeInterval
    /// Current average translation since the swipe anchor (nil when not tracking a swipe).
    var swipeTranslation: CGVector?
}

/// Turns a stream of `TrackpadFrame`s from **one** device into gestures.
///
/// Pure logic: no timers, no threads, no system APIs. Time comes from frame
/// timestamps, which keeps it deterministic and unit-testable.
///
/// Recognition rules
/// - **Tap**: evaluated when the last finger lifts. Needs ≥ `minimumFingers`, all
///   fingers landing within `tapMaximumLandingSpread`, the whole session shorter than
///   `tapMaximumDuration`, no finger moving more than `tapMaximumMovement`, and no
///   physical click. The finger count is the *maximum* seen during the session, so
///   a 4-finger tap is never reported as a 3-finger tap.
/// - **Swipe**: evaluated while fingers move. The finger count must be stable for
///   `settleTime`; then the average finger translation must reach
///   `swipeMinimumDistance` within `swipeMaximumDuration`, along one dominant axis
///   (`swipeDirectionRatio`), fast enough (`swipeMinimumVelocity`), with every
///   finger agreeing on the direction (`swipeFingerAgreement`). Once any finger
///   lifts, no swipe can be recognised in that session.
/// - One session fires at most one gesture, and `cooldown` suppresses sessions that
///   start right after a gesture.
final class GestureRecognizer {
    var configuration: GestureConfiguration
    var onEvent: ((GestureRecognizerEvent) -> Void)?
    /// Set only when live diagnostics are wanted (Debug builds).
    var onDiagnostics: ((GestureDiagnostics) -> Void)?

    private(set) var state: GestureState = .idle

    private struct Anchor {
        var time: TimeInterval
        var positions: [Int: CGPoint]
    }

    private struct Session {
        var startTime: TimeInterval = 0
        var maxFingers = 0
        var lastCount = 0
        var countStableSince: TimeInterval = 0
        var landingTimes: [Int: TimeInterval] = [:]
        var origins: [Int: CGPoint] = [:]
        var maxMovement: Double = 0
        var clickDetected = false
        var fingerLifted = false
        var anchor: Anchor?
    }

    private var session = Session()
    private var lastRecognitionTime: TimeInterval = -.infinity
    private var lastFrameTime: TimeInterval?
    private var currentSwipeTranslation: CGVector?

    init(configuration: GestureConfiguration = .default) {
        self.configuration = configuration
    }

    /// Informs the recognizer that the trackpad was physically clicked.
    /// A clicked session can never become a tap.
    func noteClick() {
        if state == .tracking {
            session.clickDetected = true
        }
    }

    func reset() {
        state = .idle
        session = Session()
        currentSwipeTranslation = nil
    }

    func process(_ frame: TrackpadFrame) {
        let time = frame.timestamp
        if let last = lastFrameTime, time - last > configuration.staleSessionTimeout, state != .idle {
            Log.verbose(Log.gesture, "stale session discarded after \(time - last)s without frames")
            reset()
        }
        lastFrameTime = time

        let contacts = frame.contacts
        currentSwipeTranslation = nil

        switch state {
        case .idle:
            if !contacts.isEmpty {
                let sinceLast = time - lastRecognitionTime
                if sinceLast < configuration.cooldown {
                    state = .waitingForRelease
                    emit(.debounced(sinceLastGesture: sinceLast))
                } else {
                    beginSession(at: time, fingers: contacts.count)
                    track(contacts, at: time)
                }
            }

        case .tracking:
            track(contacts, at: time)

        case .recognized, .waitingForRelease:
            if contacts.isEmpty {
                state = .idle
            }
        }

        if let onDiagnostics {
            onDiagnostics(GestureDiagnostics(
                timestamp: time,
                deviceID: frame.deviceID,
                state: state,
                contacts: contacts,
                maxFingers: session.maxFingers,
                sessionDuration: state == .idle ? 0 : time - session.startTime,
                swipeTranslation: currentSwipeTranslation
            ))
        }
    }

    // MARK: - Session handling

    private func beginSession(at time: TimeInterval, fingers: Int) {
        session = Session()
        session.startTime = time
        session.countStableSince = time
        state = .tracking
        emit(.began(fingers: fingers))
    }

    private func track(_ contacts: [TouchPoint], at time: TimeInterval) {
        let count = contacts.count
        if count == 0 {
            finishSession(at: time)
            return
        }

        // Per-finger bookkeeping for tap evaluation.
        for contact in contacts {
            if let origin = session.origins[contact.id] {
                session.maxMovement = max(session.maxMovement, scaledDistance(from: origin, to: contact.position))
            } else {
                session.origins[contact.id] = contact.position
                session.landingTimes[contact.id] = time
            }
        }

        if count > configuration.maximumFingers {
            reject(.tooManyFingers, metrics: metrics(fingers: count, duration: time - session.startTime))
            return
        }

        if count != session.lastCount {
            if count < session.lastCount {
                session.fingerLifted = true
            }
            session.lastCount = count
            session.countStableSince = time
            session.anchor = nil
        }
        session.maxFingers = max(session.maxFingers, count)

        // Swipes need the full, stable finger set.
        guard !session.fingerLifted,
              count == session.maxFingers,
              count >= configuration.minimumFingers else { return }

        let currentPositions = Dictionary(contacts.map { ($0.id, $0.position) }, uniquingKeysWith: { first, _ in first })

        if let anchor = session.anchor, Set(anchor.positions.keys) != Set(currentPositions.keys) {
            session.anchor = nil // a finger was replaced; start over
        }

        guard let anchor = session.anchor else {
            if time - session.countStableSince >= configuration.settleTime {
                session.anchor = Anchor(time: time, positions: currentPositions)
            }
            return
        }

        evaluateSwipe(anchor: anchor, positions: currentPositions, fingers: count, at: time)
    }

    private func evaluateSwipe(anchor: Anchor, positions: [Int: CGPoint], fingers: Int, at time: TimeInterval) {
        var displacements: [CGVector] = []
        displacements.reserveCapacity(positions.count)
        for (id, position) in positions {
            guard let origin = anchor.positions[id] else { continue }
            displacements.append(scaledDelta(from: origin, to: position))
        }
        guard !displacements.isEmpty else { return }

        let n = CGFloat(displacements.count)
        let mean = CGVector(
            dx: displacements.reduce(0) { $0 + $1.dx } / n,
            dy: displacements.reduce(0) { $0 + $1.dy } / n
        )
        currentSwipeTranslation = mean

        let elapsed = time - anchor.time
        let candidate = GestureMetrics(fingers: fingers, duration: elapsed, translation: mean, maxFingerMovement: session.maxMovement)
        let distance = candidate.distance

        guard distance >= configuration.swipeMinimumDistance else {
            // Sliding window: slow drift never accumulates into a swipe.
            if elapsed > configuration.swipeMaximumDuration {
                session.anchor = Anchor(time: time, positions: positions)
            }
            return
        }

        let absX = Double(abs(mean.dx))
        let absY = Double(abs(mean.dy))
        guard max(absX, absY) >= configuration.swipeDirectionRatio * min(absX, absY) else {
            reject(.diagonalSwipe, metrics: candidate)
            return
        }
        guard candidate.velocity >= configuration.swipeMinimumVelocity else {
            reject(.swipeTooSlow, metrics: candidate)
            return
        }

        let direction: SwipeDirection = absX >= absY
            ? (mean.dx > 0 ? .right : .left)
            : (mean.dy > 0 ? .up : .down)
        let axis = direction.unitVector
        for displacement in displacements {
            let projection = Double(displacement.dx * axis.dx + displacement.dy * axis.dy)
            if projection < configuration.swipeFingerAgreement * distance {
                reject(.inconsistentFingers, metrics: candidate)
                return
            }
        }

        recognize(.swipe(fingers: fingers, direction: direction), metrics: candidate, at: time)
    }

    private func finishSession(at time: TimeInterval) {
        // Every finger is up: whatever happens below, the next frame starts fresh.
        defer { state = .idle }

        let fingers = session.maxFingers
        // One- and two-finger input is ordinary clicking / scrolling: stay silent.
        guard fingers >= configuration.minimumFingers else { return }

        let duration = time - session.startTime
        let candidate = metrics(fingers: fingers, duration: duration)

        if session.clickDetected {
            reject(.physicalClick, metrics: candidate)
        } else if session.landingTimes.count != fingers {
            reject(.fingersReplaced, metrics: candidate)
        } else if duration > configuration.tapMaximumDuration {
            reject(.tapTooLong, metrics: candidate)
        } else if session.maxMovement > configuration.tapMaximumMovement {
            reject(.tapMoved, metrics: candidate)
        } else if landingSpread() > configuration.tapMaximumLandingSpread {
            reject(.fingersLandedApart, metrics: candidate)
        } else {
            recognize(.tap(fingers: fingers), metrics: candidate, at: time)
        }
    }

    // MARK: - Outcomes

    private func recognize(_ gesture: TrackpadGesture, metrics: GestureMetrics, at time: TimeInterval) {
        state = .recognized(gesture)
        lastRecognitionTime = time
        emit(.recognized(gesture, metrics))
    }

    private func reject(_ reason: GestureRejection, metrics: GestureMetrics) {
        state = .waitingForRelease
        emit(.rejected(reason, metrics))
    }

    private func emit(_ event: GestureRecognizerEvent) {
        onEvent?(event)
    }

    // MARK: - Geometry helpers

    private func metrics(fingers: Int, duration: TimeInterval) -> GestureMetrics {
        GestureMetrics(fingers: fingers, duration: duration, translation: .zero, maxFingerMovement: session.maxMovement)
    }

    private func landingSpread() -> TimeInterval {
        guard let first = session.landingTimes.values.min(),
              let last = session.landingTimes.values.max() else { return 0 }
        return last - first
    }

    private func scaledDelta(from start: CGPoint, to end: CGPoint) -> CGVector {
        CGVector(dx: (end.x - start.x) * CGFloat(configuration.aspectRatio), dy: end.y - start.y)
    }

    private func scaledDistance(from start: CGPoint, to end: CGPoint) -> Double {
        let delta = scaledDelta(from: start, to: end)
        return hypot(Double(delta.dx), Double(delta.dy))
    }
}
