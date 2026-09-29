import CoreFoundation
import Foundation

/// A macOS trackpad feature that can claim the same motion as a rexTrackpad gesture.
enum SystemGestureFeature: String, Sendable {
    case lookUp
    case threeFingerDrag
    case swipeBetweenPagesOrApps
    case missionControl
    case appExpose

    /// Localised name shown in the menu.
    var displayName: String {
        switch self {
        case .lookUp: return String(localized: "Look Up & Data Detectors (tap with three fingers)")
        case .threeFingerDrag: return String(localized: "Three-finger drag")
        case .swipeBetweenPagesOrApps: return String(localized: "Swipe between pages / full-screen apps")
        case .missionControl: return String(localized: "Mission Control")
        case .appExpose: return String(localized: "App Exposé")
        }
    }
}

/// A macOS system gesture that uses the same physical motion as a rexTrackpad gesture.
struct SystemGestureConflict: Equatable, Sendable {
    let gesture: TrackpadGesture
    let feature: SystemGestureFeature
}

/// Reads another application's preferences (abstracted for tests).
protocol PreferencesReading {
    func value(forKey key: String, domain: String) -> Any?
}

/// Reads real system preferences. Works because rexTrackpad is not sandboxed.
struct SystemPreferencesReader: PreferencesReading {
    func value(forKey key: String, domain: String) -> Any? {
        CFPreferencesAppSynchronize(domain as CFString)
        return CFPreferencesCopyAppValue(key as CFString, domain as CFString)
    }
}

/// Decides whether a gesture collides with a macOS trackpad gesture, based on the
/// user's current System Settings › Trackpad / Accessibility configuration.
///
/// rexTrackpad only *observes* touches, so when a gesture collides the system
/// gesture still runs (e.g. Mission Control opens) **and** the browser action would
/// run too. With "Avoid macOS Gesture Conflicts" on (the default), such gestures are
/// ignored, which keeps normal Mac behaviour intact.
///
/// When a key is missing (never changed by the user) the macOS default is assumed,
/// and for swipes the default is "in use", i.e. conflicting. Being conservative is
/// intentional: not interfering with normal Mac operation matters more than
/// enabling a gesture.
final class SystemGestureConflictDetector {
    static let trackpadDomains = [
        "com.apple.AppleMultitouchTrackpad",
        "com.apple.driver.AppleBluetoothMultitouch.trackpad",
    ]
    static let dockDomain = "com.apple.dock"

    private let reader: PreferencesReading

    init(reader: PreferencesReading = SystemPreferencesReader()) {
        self.reader = reader
    }

    func conflict(for gesture: TrackpadGesture) -> SystemGestureConflict? {
        systemFeature(for: gesture).map { SystemGestureConflict(gesture: gesture, feature: $0) }
    }

    func conflicts(for gestures: [TrackpadGesture]) -> [TrackpadGesture: SystemGestureConflict] {
        var result: [TrackpadGesture: SystemGestureConflict] = [:]
        for gesture in gestures {
            if let conflict = conflict(for: gesture) {
                result[gesture] = conflict
            }
        }
        return result
    }

    // MARK: - Rules

    private func systemFeature(for gesture: TrackpadGesture) -> SystemGestureFeature? {
        switch gesture {
        case .tap(let fingers), .zoneTap(let fingers, _):
            // "Look up & data detectors → Tap with three fingers" (default is Force Click = 0).
            if fingers == 3, trackpadSetting("TrackpadThreeFingerTapGesture", defaultValue: 0) != 0 {
                return .lookUp
            }
            return nil

        case .circle(let fingers, _):
            // A circle starts like a swipe, so any macOS swipe with the same number of
            // fingers reacts to it as well.
            for direction in [SwipeDirection.left, .up, .down] {
                if let feature = systemFeature(for: .swipe(fingers: fingers, direction: direction)) {
                    return feature
                }
            }
            return nil

        case .swipe(let fingers, let direction):
            if fingers == 3, trackpadSetting("TrackpadThreeFingerDrag", defaultValue: 0) != 0 {
                return .threeFingerDrag
            }
            guard fingers == 3 || fingers == 4 else { return nil }
            let prefix = fingers == 3 ? "TrackpadThreeFinger" : "TrackpadFourFinger"

            switch direction {
            case .left, .right:
                if trackpadSetting("\(prefix)HorizSwipeGesture", defaultValue: 2) != 0 {
                    return .swipeBetweenPagesOrApps
                }
            case .up:
                if trackpadSetting("\(prefix)VertSwipeGesture", defaultValue: 2) != 0,
                   dockSetting("showMissionControlGestureEnabled") != false {
                    return .missionControl
                }
            case .down:
                if trackpadSetting("\(prefix)VertSwipeGesture", defaultValue: 2) != 0,
                   dockSetting("showAppExposeGestureEnabled") != false {
                    return .appExpose
                }
            }
            return nil
        }
    }

    /// The most "in use" value across built-in and Bluetooth trackpad domains.
    private func trackpadSetting(_ key: String, defaultValue: Int) -> Int {
        let values = Self.trackpadDomains.compactMap { domain -> Int? in
            (reader.value(forKey: key, domain: domain) as? NSNumber)?.intValue
        }
        guard !values.isEmpty else { return defaultValue }
        return values.first(where: { $0 != 0 }) ?? 0
    }

    /// `nil` when unset (macOS default applies).
    private func dockSetting(_ key: String) -> Bool? {
        (reader.value(forKey: key, domain: Self.dockDomain) as? NSNumber)?.boolValue
    }
}
