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
        XCTAssertEqual(mapping.action(for: .fourFingerTap), .browser(.hardReload))
        XCTAssertEqual(mapping.action(for: .threeFingerSwipeLeft), .browser(.previousTab))
        XCTAssertEqual(mapping.action(for: .threeFingerSwipeRight), .browser(.nextTab))
        XCTAssertEqual(mapping.action(for: .threeFingerSwipeUp), .browser(.newTab))
        XCTAssertEqual(mapping.action(for: .threeFingerSwipeDown), .browser(.closeTab))
        XCTAssertEqual(mapping.action(for: .fourFingerSwipeLeft), .browser(.back))
        XCTAssertEqual(mapping.action(for: .fourFingerSwipeRight), .browser(.forward))
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
                XCTAssertNotNil(BrowserCommandResolver.standard.shortcut(for: action, in: browser), "\(browser) \(action)")
            }
        }
    }

    func testBrowserSpecificShortcuts() {
        let resolver = BrowserCommandResolver.standard
        XCTAssertEqual(resolver.shortcut(for: .hardReload, in: .safari), KeyboardShortcut(.character("r"), [.command, .option]))
        XCTAssertEqual(resolver.shortcut(for: .hardReload, in: .chrome), KeyboardShortcut(.character("r"), [.command, .shift]))
        XCTAssertEqual(resolver.shortcut(for: .nextTab, in: .firefox), KeyboardShortcut(.rightArrow, [.command, .option]))
        XCTAssertEqual(resolver.shortcut(for: .nextTab, in: .edge), KeyboardShortcut(.tab, [.control]))
        XCTAssertEqual(resolver.shortcut(for: .back, in: .safari), KeyboardShortcut(.character("["), [.command]))
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
}
