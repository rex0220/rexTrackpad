import CoreGraphics
import XCTest
@testable import rexTrackpad

final class MappingAndResolverTests: XCTestCase {
    // MARK: - Identifiers

    func testGestureIdentifiersRoundTrip() {
        for gesture in TrackpadGesture.configurable + [.tap(fingers: 5), .swipe(fingers: 5, direction: .up)] {
            XCTAssertEqual(TrackpadGesture(identifier: gesture.identifier), gesture)
        }
        XCTAssertNil(TrackpadGesture(identifier: "pinch.4"))
        XCTAssertNil(TrackpadGesture(identifier: "swipe.3.sideways"))
        XCTAssertEqual(TrackpadGesture(identifier: "tap.3.left"), .threeFingerTapLeft)
        XCTAssertNil(TrackpadGesture(identifier: "tap.3.top"))
        XCTAssertEqual(TrackpadGesture(identifier: "circle.3.clockwise"), .threeFingerCircleClockwise)
        XCTAssertNil(TrackpadGesture(identifier: "circle.3.sideways"))
    }

    func testActionIdentifiersRoundTrip() {
        for action in GestureAction.allBuiltIn {
            XCTAssertEqual(GestureAction(identifier: action.identifier), action)
        }
        XCTAssertNil(GestureAction(identifier: "shell.rm"))
    }

    // MARK: - Mapping

    func testDefaultMappingMatchesSpec() {
        let mapping = GestureMapping.defaults
        XCTAssertEqual(mapping.action(for: .threeFingerTap), .browser(.reload))
        XCTAssertEqual(mapping.action(for: .threeFingerTapLeft), .browser(.previousTab))
        XCTAssertEqual(mapping.action(for: .threeFingerTapRight), .browser(.nextTab))
        XCTAssertEqual(mapping.action(for: .fourFingerTap), .browser(.openLinkInNewTab))
        XCTAssertEqual(mapping.action(for: .threeFingerSwipeLeft), .browser(.previousTab))
        XCTAssertEqual(mapping.action(for: .threeFingerSwipeRight), .browser(.nextTab))
        XCTAssertEqual(mapping.action(for: .threeFingerSwipeUp), .browser(.newTab))
        XCTAssertEqual(mapping.action(for: .threeFingerSwipeDown), .browser(.closeTab))
        XCTAssertEqual(mapping.action(for: .fourFingerSwipeLeft), .browser(.back))
        XCTAssertEqual(mapping.action(for: .fourFingerSwipeRight), .browser(.forward))
        XCTAssertEqual(mapping.action(for: .threeFingerCircleClockwise), .browser(.reopenClosedTab))
        XCTAssertEqual(mapping.action(for: .threeFingerCircleCounterClockwise), .browser(.hardReload))
        XCTAssertEqual(mapping.action(for: .oneFingerCircleClockwise), .browser(.forward))
        XCTAssertEqual(mapping.action(for: .oneFingerCircleCounterClockwise), .browser(.back))
    }

    func testUnboundZoneTapFallsBackToThePlainTap() {
        // e.g. assignments saved by 0.2.0, before zone taps existed.
        let mapping = GestureMapping([.threeFingerTap: .browser(.reload)])
        XCTAssertEqual(mapping.action(for: .threeFingerTapLeft), .browser(.reload))
        XCTAssertNil(mapping.ownAction(for: .threeFingerTapLeft))
        XCTAssertNil(mapping.action(for: .zoneTap(fingers: 4, zone: .right)))
    }

    func testMappingCodableRoundTripAndForwardCompatibility() throws {
        var mapping = GestureMapping.defaults
        mapping.bind(.threeFingerSwipeDown, to: nil)
        let data = try JSONEncoder().encode(mapping)
        XCTAssertEqual(try JSONDecoder().decode(GestureMapping.self, from: data), mapping)

        let future = #"{"tap.3":"browser.reload","pinch.4.in":"browser.newTab","tap.4":"app.launch"}"#
        let decoded = try JSONDecoder().decode(GestureMapping.self, from: Data(future.utf8))
        XCTAssertEqual(decoded, GestureMapping([.threeFingerTap: .browser(.reload)]))
    }

    func testOnlyChangedThresholdsAreStored() throws {
        let suite = "rexTrackpadTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)

        var configuration = GestureConfiguration.default
        configuration.circleMinimumRadius = 0.02
        settings.gestureConfiguration = configuration

        let stored = try XCTUnwrap(defaults.data(forKey: SettingsStore.Key.gestureConfiguration))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: stored) as? [String: Double])
        XCTAssertEqual(json, ["circleMinimumRadius": 0.02])
        XCTAssertEqual(settings.gestureConfiguration, configuration)

        settings.gestureConfiguration = .default
        XCTAssertNil(defaults.data(forKey: SettingsStore.Key.gestureConfiguration))
    }

    func testConfigurationDecodesPartialJSON() throws {
        let json = #"{"cooldown":0.5}"#
        let configuration = try JSONDecoder().decode(GestureConfiguration.self, from: Data(json.utf8))
        XCTAssertEqual(configuration.cooldown, 0.5)
        XCTAssertEqual(configuration.swipeMinimumDistance, GestureConfiguration.default.swipeMinimumDistance)
    }

    // MARK: - Browsers

    func testBundleIdentifiers() {
        XCTAssertEqual(Browser(bundleIdentifier: "com.google.Chrome"), .chrome)
        XCTAssertEqual(Browser(bundleIdentifier: "com.apple.Safari"), .safari)
        XCTAssertEqual(Browser(bundleIdentifier: "com.microsoft.edgemac"), .edge)
        XCTAssertEqual(Browser(bundleIdentifier: "org.mozilla.firefox"), .firefox)
        XCTAssertNil(Browser(bundleIdentifier: "com.apple.finder"))
    }

    func testEveryBrowserHasEveryAction() {
        for browser in Browser.allCases {
            for action in BrowserAction.allCases {
                XCTAssertNotNil(BrowserCommandResolver.standard.command(for: action, in: browser), "\(browser) \(action)")
            }
        }
    }

    func testBrowserSpecificShortcuts() {
        let resolver = BrowserCommandResolver.standard
        XCTAssertEqual(resolver.command(for: .hardReload, in: .safari), .shortcut(KeyboardShortcut(.character("r"), [.command, .option])))
        XCTAssertEqual(resolver.command(for: .hardReload, in: .chrome), .shortcut(KeyboardShortcut(.character("r"), [.command, .shift])))
        XCTAssertEqual(resolver.command(for: .nextTab, in: .firefox), .shortcut(KeyboardShortcut(.rightArrow, [.command, .option])))
        XCTAssertEqual(resolver.command(for: .nextTab, in: .edge), .shortcut(KeyboardShortcut(.tab, [.control])))
        XCTAssertEqual(resolver.command(for: .back, in: .safari), .shortcut(KeyboardShortcut(.character("["), [.command])))
        for browser in Browser.allCases {
            XCTAssertEqual(resolver.command(for: .openLinkInNewTab, in: browser), .click([.command, .shift]))
            XCTAssertEqual(resolver.command(for: .reopenClosedTab, in: browser), .shortcut(KeyboardShortcut(.character("t"), [.command, .shift])))
        }
    }

    // MARK: - Keystrokes

    func testKeystrokeResolutionUsesLayoutAndArrowFlags() {
        struct JISLikeLayout: KeyCodeResolving {
            func keyCode(for character: Character) -> CGKeyCode? { character == "[" ? 0x1E : nil }
        }
        let resolver = KeystrokeResolver(keyCodes: JISLikeLayout())

        let back = resolver.resolve(KeyboardShortcut(.character("["), [.command]))
        XCTAssertEqual(back, ResolvedKeystroke(keyCode: 0x1E, flags: .maskCommand))

        let next = resolver.resolve(KeyboardShortcut(.rightArrow, [.command, .option]))
        XCTAssertEqual(next?.keyCode, KeyCode.rightArrow)
        XCTAssertTrue(next?.flags.contains([.maskCommand, .maskAlternate, .maskSecondaryFn, .maskNumericPad]) ?? false)

        XCTAssertNil(resolver.resolve(KeyboardShortcut(.character("q"), [.command])))
    }

    func testEveryActionHasAFeedbackSymbol() {
        for action in BrowserAction.allCases {
            XCTAssertNotNil(NSImage(systemSymbolName: action.feedbackSymbol, accessibilityDescription: nil), "\(action)")
        }
    }

    func testFeedbackIsOnByDefault() throws {
        let suite = "rexTrackpadTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        XCTAssertTrue(settings.showsGestureFeedback)
        settings.showsGestureFeedback = false
        XCTAssertFalse(SettingsStore(defaults: defaults).showsGestureFeedback)
    }

    func testModifierStepsForAClick() {
        // ⌘⇧-click: ⇧ then ⌘ down (⌃⌥⇧⌘ order), released in reverse.
        let flags: CGEventFlags = [.maskCommand, .maskShift]
        XCTAssertEqual(ModifierKeys.pressSteps(for: flags), [
            KeyEventStep(keyCode: KeyCode.shift, keyDown: true, flags: .maskShift),
            KeyEventStep(keyCode: KeyCode.command, keyDown: true, flags: [.maskShift, .maskCommand]),
        ])
        XCTAssertEqual(ModifierKeys.releaseSteps(for: flags), [
            KeyEventStep(keyCode: KeyCode.command, keyDown: false, flags: .maskShift),
            KeyEventStep(keyCode: KeyCode.shift, keyDown: false, flags: []),
        ])
    }

    func testEventSequencePressesModifiersLikeAPerson() {
        // ⌃⇧⇥ (previous tab): ⌃ down, ⇧ down, ⇥ down/up, ⇧ up, ⌃ up.
        let stroke = ResolvedKeystroke(keyCode: KeyCode.tab, flags: [.maskControl, .maskShift])
        XCTAssertEqual(stroke.eventSequence, [
            KeyEventStep(keyCode: KeyCode.control, keyDown: true, flags: .maskControl),
            KeyEventStep(keyCode: KeyCode.shift, keyDown: true, flags: [.maskControl, .maskShift]),
            KeyEventStep(keyCode: KeyCode.tab, keyDown: true, flags: [.maskControl, .maskShift]),
            KeyEventStep(keyCode: KeyCode.tab, keyDown: false, flags: [.maskControl, .maskShift]),
            KeyEventStep(keyCode: KeyCode.shift, keyDown: false, flags: .maskControl),
            KeyEventStep(keyCode: KeyCode.control, keyDown: false, flags: []),
        ])

        // Arrow-key flags stay on the arrow key only; every modifier is released.
        let arrow = ResolvedKeystroke(keyCode: KeyCode.rightArrow, flags: [.maskCommand, .maskAlternate, .maskSecondaryFn, .maskNumericPad])
        let steps = arrow.eventSequence
        XCTAssertEqual(steps.count, 6)
        XCTAssertEqual(steps[2].flags, arrow.flags)
        XCTAssertEqual(steps.last, KeyEventStep(keyCode: KeyCode.option, keyDown: false, flags: []))
        XCTAssertEqual(steps.filter(\.keyDown).count, steps.filter { !$0.keyDown }.count)
    }
}
