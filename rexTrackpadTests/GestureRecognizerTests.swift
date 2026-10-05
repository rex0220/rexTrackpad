import CoreGraphics
import XCTest
@testable import rexTrackpad

final class GestureRecognizerTests: XCTestCase {
    private let frameInterval = 1.0 / 120.0
    private var recognizer: GestureRecognizer!
    private var events: [GestureRecognizerEvent] = []

    override func setUp() {
        super.setUp()
        recognizer = GestureRecognizer(configuration: .default)
        events = []
        recognizer.onEvent = { [unowned self] in self.events.append($0) }
    }

    // MARK: - Helpers

    private var recognized: [TrackpadGesture] {
        events.compactMap { event -> TrackpadGesture? in
            if case .recognized(let gesture, _) = event { return gesture }
            return nil
        }
    }

    private var rejections: [GestureRejection] {
        events.compactMap { event -> GestureRejection? in
            if case .rejected(let reason, _) = event { return reason }
            return nil
        }
    }

    private var debounceCount: Int {
        events.filter { event -> Bool in
            if case .debounced = event { return true }
            return false
        }.count
    }

    private func frame(_ time: TimeInterval, _ points: [(Int, CGFloat, CGFloat)], device: Int = 1) -> TrackpadFrame {
        TrackpadFrame(
            timestamp: time,
            deviceID: device,
            touches: points.map { TouchPoint(id: $0.0, position: CGPoint(x: $0.1, y: $0.2), phase: .touching) }
        )
    }

    private func send(_ time: TimeInterval, _ points: [(Int, CGFloat, CGFloat)]) {
        recognizer.process(frame(time, points))
    }

    private func fingers(_ count: Int, x: CGFloat = 0.3, y: CGFloat = 0.5) -> [(Int, CGFloat, CGFloat)] {
        (0..<count).map { ($0 + 1, x + CGFloat($0) * 0.1, y) }
    }

    /// Holds `count` fingers still from `start` to `end`, then lifts them.
    private func tap(fingers count: Int, start: TimeInterval, end: TimeInterval) {
        var t = start
        while t < end {
            send(t, fingers(count))
            t += frameInterval
        }
        send(end, [])
    }

    /// Moves `count` fingers by (dx, dy) per frame for `frames` frames, then lifts.
    private func swipe(fingers count: Int, dx: CGFloat, dy: CGFloat, frames: Int, start: TimeInterval = 0) {
        var t = start
        for i in 0...frames {
            let points = fingers(count, x: 0.2 + dx * CGFloat(i), y: 0.4 + dy * CGFloat(i))
            send(t, points)
            t += frameInterval
        }
        send(t, [])
    }

    /// Three fingers moving together around a circle. `radius` is in trackpad heights.
    private func drawCircle(clockwise: Bool, radius: CGFloat = 0.12, turns: Double = 1.0,
                            duration: TimeInterval = 0.8, start: TimeInterval = 0, fingerCount: Int = 3) {
        let frames = Int(duration / frameInterval)
        var t = start
        for i in 0...frames {
            let angle = (clockwise ? -1.0 : 1.0) * Double(i) / Double(frames) * turns * 2 * .pi
            let centreX = 0.5 + radius * CGFloat(cos(angle)) / 1.6 // x is scaled by the 1.6 aspect ratio
            let centreY = 0.5 + radius * CGFloat(sin(angle))
            // fingers(n) are centred at x + (n - 1) * 0.05
            send(t, fingers(fingerCount, x: centreX - CGFloat(fingerCount - 1) * 0.05, y: centreY))
            t += frameInterval
        }
        send(t, [])
    }

    private var circles: [TrackpadGesture] {
        recognized.filter { gesture -> Bool in
            if case .circle = gesture { return true }
            return false
        }
    }

    // MARK: - Taps

    func testThreeFingerTapIsRecognized() {
        tap(fingers: 3, start: 0, end: 0.12)
        XCTAssertEqual(recognized, [.threeFingerTap])
        XCTAssertEqual(recognizer.state, .idle)
    }

    func testTapZonesFollowTheFingerCentre() {
        tap(fingers: 3, start: 0, end: 0.1)                       // centre x 0.4 → middle
        send(1.0, fingers(3, x: 0.05)); send(1.1, [])               // centre x 0.15 → left side
        send(2.0, fingers(3, x: 0.70)); send(2.1, [])               // centre x 0.80 → right side
        XCTAssertEqual(recognized, [.threeFingerTap, .threeFingerTapLeft, .threeFingerTapRight])
    }

    func testTapZonesUseTheVerticalPositionToo() {
        send(0.0, fingers(3, y: 0.85)); send(0.1, [])               // centre (0.4, 0.85) → top edge
        send(1.0, fingers(3, y: 0.10)); send(1.1, [])               // centre (0.4, 0.10) → bottom edge
        send(2.0, fingers(3, x: 0.05, y: 0.85)); send(2.1, [])      // centre (0.15, 0.85) → top-left
        send(3.0, fingers(3, x: 0.70, y: 0.85)); send(3.1, [])      // centre (0.80, 0.85) → top-right
        send(4.0, fingers(3, x: 0.05, y: 0.10)); send(4.1, [])      // centre (0.15, 0.10) → bottom-left
        send(5.0, fingers(3, x: 0.70, y: 0.10)); send(5.1, [])      // centre (0.80, 0.10) → bottom-right
        XCTAssertEqual(recognized, [
            .threeFingerTapTop, .threeFingerTapBottom,
            .threeFingerTapTopLeft, .threeFingerTapTopRight,
            .threeFingerTapBottomLeft, .threeFingerTapBottomRight,
        ])
    }

    func testTapMetricsCarryTheLandingCentre() {
        send(0.0, fingers(3, x: 0.70, y: 0.85)); send(0.1, [])
        guard case .recognized(_, let metrics)? = events.last, let position = metrics.position else {
            return XCTFail("no tap position")
        }
        XCTAssertEqual(Double(position.x), 0.80, accuracy: 0.001)
        XCTAssertEqual(Double(position.y), 0.85, accuracy: 0.001)
    }

    func testFourFingerTapIsNotReportedAsThreeFingerTap() {
        send(0.00, fingers(3))
        send(0.01, fingers(3))
        send(0.03, fingers(4))
        send(0.08, fingers(4))
        send(0.14, [])
        XCTAssertEqual(recognized, [.fourFingerTap])
    }

    func testTwoFingerTapIsIgnoredSilently() {
        tap(fingers: 2, start: 0, end: 0.1)
        XCTAssertTrue(recognized.isEmpty)
        XCTAssertTrue(rejections.isEmpty)
    }

    func testLongPressIsNotATap() {
        tap(fingers: 3, start: 0, end: 0.8)
        XCTAssertTrue(recognized.isEmpty)
        XCTAssertEqual(rejections, [.tapTooLong])
    }

    func testPhysicalClickCancelsTap() {
        send(0.00, fingers(3))
        recognizer.noteClick()
        send(0.05, fingers(3))
        send(0.10, [])
        XCTAssertTrue(recognized.isEmpty)
        XCTAssertEqual(rejections, [.physicalClick])
    }

    func testFingersLandingFarApartIsNotATap() {
        send(0.00, fingers(1))
        send(0.20, fingers(3))
        send(0.25, [])
        XCTAssertTrue(recognized.isEmpty)
        XCTAssertEqual(rejections, [.fingersLandedApart])
    }

    func testTooManyFingersIsRejected() {
        send(0.00, fingers(6))
        send(0.05, [])
        XCTAssertTrue(recognized.isEmpty)
        XCTAssertEqual(rejections, [.tooManyFingers])
    }

    // MARK: - Swipes

    func testThreeFingerSwipeRightFiresExactlyOnce() {
        swipe(fingers: 3, dx: 0.01, dy: 0, frames: 40)
        XCTAssertEqual(recognized, [.threeFingerSwipeRight])
        XCTAssertEqual(recognizer.state, .idle)
    }

    func testSwipeIsReportedOnlyWhenFingersLift() {
        var t: TimeInterval = 0
        for i in 0...30 {
            send(t, fingers(3, x: 0.2 + CGFloat(i) * 0.01))
            t += frameInterval
        }
        // Recognised while moving, but not reported until every finger is up.
        XCTAssertEqual(recognizer.state, .recognized(.threeFingerSwipeRight))
        XCTAssertTrue(recognized.isEmpty)

        send(t, [])
        XCTAssertEqual(recognized, [.threeFingerSwipeRight])
        XCTAssertEqual(recognizer.state, .idle)
    }

    func testQuickSwipeWithStaggeredLandingIsRecognized() {
        // Real hardware: fingers land ~30 ms apart and a short vertical swipe is
        // mostly done before the last finger settles (0.2 s, ~0.24 travel).
        let landing: [Int: TimeInterval] = [1: 0.00, 2: 0.03, 3: 0.06]
        let speed: CGFloat = 1.2 // trackpad heights per second
        var t: TimeInterval = 0
        while t <= 0.20 {
            let points = landing.filter { $0.value <= t }.sorted { $0.key < $1.key }.map { id, _ in
                (id, 0.3 + CGFloat(id) * 0.1, 0.3 + speed * CGFloat(t))
            }
            send(t, points)
            t += frameInterval
        }
        send(t, [])
        XCTAssertEqual(recognized, [.threeFingerSwipeUp])
    }

    func testFlickCompletedWhileLiftingIsRecognized() {
        // A short flick: one finger lifts before the swipe distance is reached while
        // all three touch, and the rest of the movement happens while lifting.
        let speed: CGFloat = 1.5
        var t: TimeInterval = 0
        while t <= 0.15 {
            let y = 0.3 + speed * CGFloat(max(0, t - 0.03))
            var points: [(Int, CGFloat, CGFloat)] = [(1, 0.3, y), (2, 0.4, y)]
            if t < 0.10 { points.append((3, 0.5, y)) }
            send(t, points)
            t += frameInterval
        }
        XCTAssertTrue(recognized.isEmpty)
        send(t, [])
        XCTAssertEqual(recognized, [.threeFingerSwipeUp])
    }

    func testThirdFingerJoiningAScrollDoesNotSwipe() {
        // Two-finger scroll upwards, then a third finger rests on the trackpad.
        var t: TimeInterval = 0
        for i in 0...40 {
            send(t, [(1, 0.4, 0.2 + CGFloat(i) * 0.01), (2, 0.5, 0.2 + CGFloat(i) * 0.01)])
            t += frameInterval
        }
        for _ in 0...20 {
            send(t, [(1, 0.4, 0.6), (2, 0.5, 0.6), (3, 0.6, 0.6)])
            t += frameInterval
        }
        send(t, [])
        XCTAssertTrue(recognized.isEmpty)
    }

    func testSwipeDirections() {
        swipe(fingers: 3, dx: -0.01, dy: 0, frames: 30, start: 0)
        swipe(fingers: 3, dx: 0, dy: 0.015, frames: 30, start: 2)
        swipe(fingers: 3, dx: 0, dy: -0.015, frames: 30, start: 4)
        swipe(fingers: 4, dx: -0.01, dy: 0, frames: 30, start: 6)
        swipe(fingers: 4, dx: 0.01, dy: 0, frames: 30, start: 8)
        XCTAssertEqual(recognized, [
            .threeFingerSwipeLeft,
            .threeFingerSwipeUp,
            .threeFingerSwipeDown,
            .fourFingerSwipeLeft,
            .fourFingerSwipeRight,
        ])
    }

    func testDiagonalSwipeIsRejected() {
        // Equal physical movement on both axes (x is scaled by the 1.6 aspect ratio).
        swipe(fingers: 3, dx: 0.01, dy: 0.016, frames: 40)
        XCTAssertTrue(recognized.isEmpty)
        XCTAssertEqual(rejections, [.diagonalSwipe])
    }

    func testSlowDriftNeverBecomesASwipe() {
        swipe(fingers: 3, dx: 0.0008, dy: 0, frames: 240)
        XCTAssertFalse(recognized.contains(where: { gesture -> Bool in
            if case .swipe = gesture { return true }
            return false
        }))
    }

    func testPinchIsNotASwipe() {
        var t: TimeInterval = 0
        for i in 0...40 {
            let spread = CGFloat(i) * 0.006
            send(t, [
                (1, 0.40 - spread, 0.5), (2, 0.45 - spread, 0.55),
                (3, 0.55 + spread, 0.55), (4, 0.60 + spread, 0.5),
            ])
            t += frameInterval
        }
        send(t, [])
        XCTAssertTrue(recognized.isEmpty)
    }

    func testLiftingFingersDoesNotProduceASecondGesture() {
        // Swipe with three fingers, then lift them one by one while still moving.
        var t: TimeInterval = 0
        for i in 0...30 {
            send(t, fingers(3, x: 0.2 + CGFloat(i) * 0.01))
            t += frameInterval
        }
        for i in 0..<10 {
            send(t, fingers(2, x: 0.5 + CGFloat(i) * 0.01))
            t += frameInterval
        }
        send(t, fingers(1, x: 0.6))
        send(t + frameInterval, [])
        XCTAssertEqual(recognized, [.threeFingerSwipeRight])
    }

    // MARK: - Circles

    func testClockwiseCircleIsRecognizedOnce() {
        drawCircle(clockwise: true)
        // The start of the circle looks like a swipe, but only the circle is reported.
        XCTAssertEqual(recognized, [.threeFingerCircleClockwise])
    }

    func testCounterClockwiseCircle() {
        drawCircle(clockwise: false)
        XCTAssertEqual(recognized, [.threeFingerCircleCounterClockwise])
    }

    func testHalfCircleIsNotACircle() {
        drawCircle(clockwise: true, turns: 0.5, duration: 0.5)
        XCTAssertTrue(circles.isEmpty)
    }

    func testTinyLoopIsNotACircle() {
        drawCircle(clockwise: false, radius: 0.02)
        XCTAssertTrue(circles.isEmpty)
    }

    func testOneFingerCircle() {
        drawCircle(clockwise: true, turns: 1.05, fingerCount: 1)
        XCTAssertEqual(recognized, [.oneFingerCircleClockwise])
    }

    func testOneFingerCircleAfterMovingThePointer() {
        // Move the pointer for 2.5 s, then draw the circle without lifting the finger.
        var t: TimeInterval = 0
        while t < 2.5 {
            send(t, [(1, 0.2 + CGFloat(t) * 0.1, 0.3)])
            t += frameInterval
        }
        let frames = Int(0.9 / frameInterval)
        for i in 0...frames {
            let angle = -Double(i) / Double(frames) * 1.1 * 2 * .pi
            send(t, [(1, 0.6 + 0.12 * CGFloat(cos(angle)) / 1.6, 0.5 + 0.12 * CGFloat(sin(angle)))])
            t += frameInterval
        }
        send(t, [])
        XCTAssertEqual(recognized, [.oneFingerCircleClockwise])
    }

    func testOneFingerNeedsAlmostAFullTurn() {
        // 310° is enough for three fingers (300°), not for one finger (330°).
        drawCircle(clockwise: false, turns: 310.0 / 360, fingerCount: 1)
        XCTAssertTrue(circles.isEmpty)
        drawCircle(clockwise: false, turns: 310.0 / 360, start: 2)
        XCTAssertEqual(circles, [.threeFingerCircleCounterClockwise])
    }

    func testSmallButRealOneFingerCircle() {
        // Just above the minimum size (0.06), drawn at hardware speed.
        drawCircle(clockwise: true, radius: 0.07, turns: 1.0, duration: 0.7, fingerCount: 1)
        XCTAssertEqual(recognized, [.oneFingerCircleClockwise])
    }

    func testCircleBelowMinimumSizeIsIgnored() {
        drawCircle(clockwise: true, radius: 0.045, turns: 1.0, duration: 0.7, fingerCount: 1)
        XCTAssertTrue(circles.isEmpty)
    }

    func testOrdinaryPointingIsIgnored() {
        // One finger wandering around for several seconds, then lifting.
        var t: TimeInterval = 0
        for i in 0...600 {
            let a = Double(i) / 40
            send(t, [(1, 0.5 + 0.2 * CGFloat(sin(a)), 0.5 + 0.1 * CGFloat(sin(a * 1.7)))])
            t += frameInterval
        }
        send(t, [])
        XCTAssertTrue(recognized.isEmpty)
        XCTAssertTrue(rejections.isEmpty)
    }

    func testClickDuringOneFingerCircleCancelsIt() {
        send(0, [(1, 0.5, 0.5)])
        recognizer.noteClick()
        drawCircle(clockwise: true, turns: 1.05, start: frameInterval, fingerCount: 1)
        XCTAssertTrue(circles.isEmpty)
    }

    func testSlowCircleIsNotRecognized() {
        drawCircle(clockwise: true, duration: 3.0)
        XCTAssertTrue(circles.isEmpty)
    }

    // MARK: - Debounce

    func testCooldownSuppressesImmediateRepeat() {
        tap(fingers: 3, start: 0.00, end: 0.10)
        tap(fingers: 3, start: 0.20, end: 0.30) // within 0.35 s cooldown
        tap(fingers: 3, start: 1.00, end: 1.10)
        XCTAssertEqual(recognized, [.threeFingerTap, .threeFingerTap])
        XCTAssertEqual(debounceCount, 1)
    }

    func testStaleSessionIsDiscarded() {
        send(0.00, fingers(3))
        // No lift frame is ever delivered; much later a new tap happens.
        tap(fingers: 4, start: 5.0, end: 5.1)
        XCTAssertEqual(recognized, [.fourFingerTap])
    }
}
