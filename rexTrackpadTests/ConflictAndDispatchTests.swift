import XCTest
@testable import rexTrackpad

private struct FakePreferences: PreferencesReading {
    var values: [String: [String: Any]] = [:]

    func value(forKey key: String, domain: String) -> Any? {
        values[domain]?[key]
    }
}

private final class FakeDetector: BrowserDetecting {
    var app: FrontmostApplication?

    func frontmostApplication() -> FrontmostApplication? { app }

    func browser(for application: FrontmostApplication) -> Browser? {
        application.bundleIdentifier.flatMap(Browser.init(bundleIdentifier:))
    }
}

private final class FakeKeyboard: KeyboardEventSending {
    var sent: [KeyboardShortcut] = []

    func send(_ shortcut: KeyboardShortcut) -> Bool {
        sent.append(shortcut)
        return true
    }
}

private final class FakePermissions: PermissionChecking {
    var canPostKeyboardEvents = true
}

final class ConflictDetectorTests: XCTestCase {
    private let trackpad = "com.apple.AppleMultitouchTrackpad"

    func testMissingPreferencesAssumeSwipesAreTakenButTapsAreFree() {
        let detector = SystemGestureConflictDetector(reader: FakePreferences())
        XCTAssertNil(detector.conflict(for: .threeFingerTap))
        XCTAssertNil(detector.conflict(for: .fourFingerTap))
        XCTAssertNotNil(detector.conflict(for: .threeFingerSwipeLeft))
        XCTAssertNotNil(detector.conflict(for: .threeFingerSwipeUp))
        XCTAssertNotNil(detector.conflict(for: .fourFingerSwipeRight))
        XCTAssertNil(detector.conflict(for: .swipe(fingers: 5, direction: .left)))
    }

    func testSystemGesturesMovedToFourFingersFreeThreeFingerSwipes() {
        let prefs = FakePreferences(values: [trackpad: [
            "TrackpadThreeFingerHorizSwipeGesture": 0,
            "TrackpadThreeFingerVertSwipeGesture": 0,
            "TrackpadFourFingerHorizSwipeGesture": 2,
            "TrackpadFourFingerVertSwipeGesture": 2,
        ]])
        let detector = SystemGestureConflictDetector(reader: prefs)
        XCTAssertNil(detector.conflict(for: .threeFingerSwipeLeft))
        XCTAssertNil(detector.conflict(for: .threeFingerSwipeDown))
        XCTAssertEqual(detector.conflict(for: .fourFingerSwipeLeft)?.systemFeature, "Swipe between pages / full-screen apps")
    }

    func testThreeFingerTapLookUpAndThreeFingerDrag() {
        let prefs = FakePreferences(values: [trackpad: [
            "TrackpadThreeFingerTapGesture": 2,
            "TrackpadThreeFingerDrag": 1,
            "TrackpadThreeFingerHorizSwipeGesture": 0,
        ]])
        let detector = SystemGestureConflictDetector(reader: prefs)
        XCTAssertNotNil(detector.conflict(for: .threeFingerTap))
        XCTAssertEqual(detector.conflict(for: .threeFingerSwipeRight)?.systemFeature, "Three-finger drag")
    }

    func testDisabledMissionControlInDockFreesSwipeUp() {
        let prefs = FakePreferences(values: [
            trackpad: ["TrackpadThreeFingerVertSwipeGesture": 2],
            "com.apple.dock": ["showMissionControlGestureEnabled": false],
        ])
        let detector = SystemGestureConflictDetector(reader: prefs)
        XCTAssertNil(detector.conflict(for: .threeFingerSwipeUp))
        XCTAssertNotNil(detector.conflict(for: .threeFingerSwipeDown))
    }
}

final class ActionDispatcherTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var settings: SettingsStore!
    private var detector: FakeDetector!
    private var keyboard: FakeKeyboard!
    private var permissions: FakePermissions!
    private var now: TimeInterval = 100
    private var dispatcher: ActionDispatcher!

    override func setUp() {
        super.setUp()
        suiteName = "rexTrackpadTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        settings = SettingsStore(defaults: defaults)
        detector = FakeDetector()
        keyboard = FakeKeyboard()
        permissions = FakePermissions()
        dispatcher = ActionDispatcher(
            settings: settings,
            browserDetector: detector,
            keyboard: keyboard,
            permissions: permissions,
            clock: { [unowned self] in self.now }
        )
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func front(_ bundleID: String?) {
        detector.app = FrontmostApplication(name: "Test", bundleIdentifier: bundleID, processIdentifier: 1)
    }

    func testReloadInChrome() {
        front("com.google.Chrome")
        let outcome = dispatcher.dispatch(.threeFingerTap)
        XCTAssertEqual(outcome, .sent(.chrome, .reload, KeyboardShortcut(.character("r"), [.command])))
        XCTAssertEqual(keyboard.sent.count, 1)
    }

    func testNonBrowserIsIgnored() {
        front("com.apple.finder")
        XCTAssertEqual(dispatcher.dispatch(.threeFingerTap), .notABrowser(bundleIdentifier: "com.apple.finder"))
        XCTAssertTrue(keyboard.sent.isEmpty)
    }

    func testDisabledBrowserIsIgnored() {
        front("com.microsoft.edgemac")
        settings.setBrowser(.edge, enabled: false)
        XCTAssertEqual(dispatcher.dispatch(.threeFingerTap), .browserDisabled(.edge))
        XCTAssertTrue(keyboard.sent.isEmpty)
    }

    func testGloballyDisabled() {
        front("com.apple.Safari")
        settings.isEnabled = false
        XCTAssertEqual(dispatcher.dispatch(.threeFingerTap), .disabled)
    }

    func testMissingPermissionDoesNotSend() {
        front("com.apple.Safari")
        permissions.canPostKeyboardEvents = false
        XCTAssertEqual(dispatcher.dispatch(.fourFingerTap), .permissionMissing)
        XCTAssertTrue(keyboard.sent.isEmpty)
    }

    func testUnboundGesture() {
        front("com.apple.Safari")
        var mapping = settings.gestureMapping
        mapping.bind(.threeFingerTap, to: nil)
        settings.gestureMapping = mapping
        XCTAssertEqual(dispatcher.dispatch(.threeFingerTap), .unmapped)
    }

    func testDispatcherDebounce() {
        front("org.mozilla.firefox")
        XCTAssertEqual(dispatcher.dispatch(.threeFingerTap), .sent(.firefox, .reload, KeyboardShortcut(.character("r"), [.command])))
        now += 0.05
        XCTAssertEqual(dispatcher.dispatch(.threeFingerTap), .debounced)
        now += 0.5
        XCTAssertEqual(dispatcher.dispatch(.fourFingerTap), .sent(.firefox, .hardReload, KeyboardShortcut(.character("r"), [.command, .shift])))
        XCTAssertEqual(keyboard.sent.count, 2)
    }
}
