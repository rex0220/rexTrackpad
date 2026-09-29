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
        /// Last position of every finger while it was touching.
        var lastPositions: [Int: CGPoint] = [:]
        var maxMovement: Double = 0
        var clickDetected = false
        var fingerLifted = false
        var anchor: Anchor?
    }

    private var session = Session()
    private var lastRecognitionTime: TimeInterval = -.infinity
    /// A swipe recognised while fingers are still down; reported when they lift.
    private var pendingSwipe: (gesture: TrackpadGesture, metrics: GestureMetrics)?
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
        pendingSwipe = nil
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
                if let pending = pendingSwipe {
                    pendingSwipe = nil
                    lastRecognitionTime = time
                    emit(.recognized(pending.gesture, pending.metrics))
                }
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
            session.lastPositions[contact.id] = contact.position
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

        let anchor: Anchor
        if let existing = session.anchor {
            anchor = existing
        } else {
            guard time - session.countStableSince >= configuration.settleTime else { return }
            anchor = makeAnchor(for: currentPositions, at: time)
            session.anchor = anchor
        }

        evaluateSwipe(anchor: anchor, positions: currentPositions, fingers: count, at: time)
    }

    /// Where swipe travel is measured from.
    ///
    /// Fingers land one after another, and a short, quick swipe is largely over by the
    /// time the last finger has settled. So when all fingers landed together (within
    /// `tapMaximumLandingSpread`), travel is measured from each finger's landing point.
    /// When a finger joined later — e.g. a third finger added to a two-finger scroll —
    /// the current positions are used, so earlier movement cannot trigger a swipe.
    private func makeAnchor(for positions: [Int: CGPoint], at time: TimeInterval) -> Anchor {
        let landings = positions.keys.compactMap { session.landingTimes[$0] }
        let origins = positions.keys.compactMap { id in session.origins[id].map { (id, $0) } }
        guard landings.count == positions.count, origins.count == positions.count,
              let first = landings.min(), let last = landings.max(),
              last - first <= configuration.tapMaximumLandingSpread else {
            return Anchor(time: time, positions: positions)
        }
        return Anchor(time: first, positions: Dictionary(uniqueKeysWithValues: origins))
    }

    private func evaluateSwipe(anchor: Anchor, positions: [Int: CGPoint], fingers: Int, at time: TimeInterval) {
        let displacements = positions.compactMap { id, position in
            anchor.positions[id].map { scaledDelta(from: $0, to: position) }
        }
        guard !displacements.isEmpty else { return }

        let elapsed = time - anchor.time
        let (verdict, candidate) = swipeVerdict(displacements, fingers: fingers, elapsed: elapsed)
        currentSwipeTranslation = candidate.translation

        switch verdict {
        case .tooShort:
            // Sliding window: slow drift never accumulates into a swipe.
            if elapsed > configuration.swipeMaximumDuration {
                session.anchor = Anchor(time: time, positions: positions)
            }
        case .rejected(let reason):
            reject(reason, metrics: candidate)
        case .recognized(let direction):
            recognize(.swipe(fingers: fingers, direction: direction), metrics: candidate, at: time)
        }
    }

    private enum SwipeVerdict {
        case tooShort
        case rejected(GestureRejection)
        case recognized(SwipeDirection)
    }

    /// Applies the swipe rules (distance, direction, speed, finger agreement) to the
    /// per-finger displacements of one candidate.
    private func swipeVerdict(_ displacements: [CGVector], fingers: Int, elapsed: TimeInterval) -> (SwipeVerdict, GestureMetrics) {
        let n = CGFloat(displacements.count)
        let mean = CGVector(
            dx: displacements.reduce(0) { $0 + $1.dx } / n,
            dy: displacements.reduce(0) { $0 + $1.dy } / n
        )
        let candidate = GestureMetrics(fingers: fingers, duration: elapsed, translation: mean, maxFingerMovement: session.maxMovement)
        let distance = candidate.distance

        guard distance >= configuration.swipeMinimumDistance else {
            return (.tooShort, candidate)
        }

        let absX = Double(abs(mean.dx))
        let absY = Double(abs(mean.dy))
        guard max(absX, absY) >= configuration.swipeDirectionRatio * min(absX, absY) else {
            return (.rejected(.diagonalSwipe), candidate)
        }
        guard candidate.velocity >= configuration.swipeMinimumVelocity else {
            return (.rejected(.swipeTooSlow), candidate)
        }

        let direction: SwipeDirection = absX >= absY
            ? (mean.dx > 0 ? .right : .left)
            : (mean.dy > 0 ? .up : .down)
        let axis = direction.unitVector
        for displacement in displacements {
            let projection = Double(displacement.dx * axis.dx + displacement.dy * axis.dy)
            if projection < configuration.swipeFingerAgreement * distance {
                return (.rejected(.inconsistentFingers), candidate)
            }
        }
        return (.recognized(direction), candidate)
    }

    /// A quick flick often reaches swipe distance only while the fingers are already
    /// lifting, after live evaluation has stopped. When every finger landed together,
    /// the whole path (landing point → last touching position) is judged once more
    /// with the same rules.
    private func swipeAtRelease(fingers: Int, at time: TimeInterval) -> (SwipeVerdict, GestureMetrics)? {
        guard fingers <= configuration.maximumFingers,
              session.landingTimes.count == fingers,
              landingSpread() <= configuration.tapMaximumLandingSpread,
              let firstLanding = session.landingTimes.values.min() else { return nil }

        let elapsed = time - firstLanding
        guard elapsed <= configuration.swipeMaximumDuration else { return nil }

        let displacements = session.origins.compactMap { id, origin in
            session.lastPositions[id].map { scaledDelta(from: origin, to: $0) }
        }
        guard displacements.count == fingers else { return nil }
        return swipeVerdict(displacements, fingers: fingers, elapsed: elapsed)
    }

    private func finishSession(at time: TimeInterval) {
        // Every finger is up: whatever happens below, the next frame starts fresh.
        defer { state = .idle }

        let fingers = session.maxFingers
        // One- and two-finger input is ordinary clicking / scrolling: stay silent.
        guard fingers >= configuration.minimumFingers else { return }

        let duration = time - session.startTime
        let candidate = metrics(fingers: fingers, duration: duration)

        if !session.clickDetected, session.maxMovement > configuration.tapMaximumMovement,
           let (verdict, swipeMetrics) = swipeAtRelease(fingers: fingers, at: time) {
            switch verdict {
            case .recognized(let direction):
                // The fingers are already up, so report right away.
                lastRecognitionTime = time
                emit(.recognized(.swipe(fingers: fingers, direction: direction), swipeMetrics))
                return
            case .rejected(let reason):
                reject(reason, metrics: swipeMetrics)
                return
            case .tooShort:
                break // judged as a (moved) tap below
            }
        }

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
        if case .swipe = gesture {
            // Reported when the fingers lift. Keyboard shortcuts sent while fingers are
            // still moving race with the trackpad's own events, and apps that read the
            // live modifier state (Chrome's ⌃Tab) then drop them intermittently.
            pendingSwipe = (gesture, metrics)
            return
        }
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
