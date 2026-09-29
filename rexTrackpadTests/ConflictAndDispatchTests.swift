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

private final class FakePointer: PointerEventSending {
    var pointerOverProcess: pid_t? = 1
    var clicks: [KeyboardModifiers] = []

    func isPointerOverWindow(ofProcess processIdentifier: pid_t) -> Bool {
        pointerOverProcess == processIdentifier
    }

    func click(with modifiers: KeyboardModifiers) -> Bool {
        clicks.append(modifiers)
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
        XCTAssertNotNil(detector.conflict(for: .threeFingerCircleClockwise))
        XCTAssertNil(detector.conflict(for: .oneFingerCircleClockwise))
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
        XCTAssertNil(detector.conflict(for: .threeFingerCircleCounterClockwise))
        XCTAssertEqual(detector.conflict(for: .fourFingerSwipeLeft)?.feature, .swipeBetweenPagesOrApps)
    }

    func testThreeFingerTapLookUpAndThreeFingerDrag() {
        let prefs = FakePreferences(values: [trackpad: [
            "TrackpadThreeFingerTapGesture": 2,
            "TrackpadThreeFingerDrag": 1,
            "TrackpadThreeFingerHorizSwipeGesture": 0,
        ]])
        let detector = SystemGestureConflictDetector(reader: prefs)
        XCTAssertNotNil(detector.conflict(for: .threeFingerTap))
        XCTAssertNotNil(detector.conflict(for: .threeFingerTapLeft))
        XCTAssertEqual(detector.conflict(for: .threeFingerSwipeRight)?.feature, .threeFingerDrag)
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
    private var pointer: FakePointer!
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
        pointer = FakePointer()
        permissions = FakePermissions()
        dispatcher = ActionDispatcher(
            settings: settings,
            browserDetector: detector,
            keyboard: keyboard,
            pointer: pointer,
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
        XCTAssertEqual(outcome, .sent(.chrome, .reload, .shortcut(KeyboardShortcut(.character("r"), [.command]))))
        XCTAssertEqual(keyboard.sent.count, 1)
    }

    func testOpenLinkInNewTabClicksAtPointer() {
        front("com.apple.Safari")
        XCTAssertEqual(dispatcher.dispatch(.fourFingerTap), .sent(.safari, .openLinkInNewTab, .click([.command, .shift])))
        XCTAssertEqual(pointer.clicks, [[.command, .shift]])
        XCTAssertTrue(keyboard.sent.isEmpty)
    }

    func testOpenLinkIsNotClickedOutsideTheBrowser() {
        front("com.google.Chrome")
        pointer.pointerOverProcess = 99 // e.g. the Dock or another app's window
        XCTAssertEqual(dispatcher.dispatch(.fourFingerTap), .pointerNotOverBrowser(.chrome))
        XCTAssertTrue(pointer.clicks.isEmpty)
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
        XCTAssertEqual(dispatcher.dispatch(.threeFingerTap), .sent(.firefox, .reload, .shortcut(KeyboardShortcut(.character("r"), [.command]))))
        now += 0.05
        XCTAssertEqual(dispatcher.dispatch(.threeFingerTap), .debounced)
        now += 0.5
        XCTAssertEqual(dispatcher.dispatch(.threeFingerTap), .sent(.firefox, .reload, .shortcut(KeyboardShortcut(.character("r"), [.command]))))
        XCTAssertEqual(keyboard.sent.count, 2)
    }
}
