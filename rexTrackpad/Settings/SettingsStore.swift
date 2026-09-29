import Combine
import Foundation

/// All persisted settings, backed by UserDefaults.
///
/// Keys (visible with `defaults read com.rex0220.rexTrackpad`):
///
/// | Key | Type |
/// |---|---|
/// | `Enabled` | Bool |
/// | `LaunchAtLogin` | Bool (last requested state; the truth is `SMAppService`) |
/// | `ChromeEnabled`, `SafariEnabled`, `EdgeEnabled`, `FirefoxEnabled` | Bool |
/// | `GestureMappings` | JSON `{"tap.3": "browser.reload", …}` |
/// | `AvoidSystemGestureConflicts` | Bool |
/// | `GestureConfiguration` | JSON of `GestureConfiguration` |
///
/// Main thread only. Every change posts `didChangeNotification`.
final class SettingsStore: ObservableObject {
    static let didChangeNotification = Notification.Name("com.rex0220.rexTrackpad.settingsDidChange")

    enum Key {
        static let enabled = "Enabled"
        static let launchAtLogin = "LaunchAtLogin"
        static let gestureMappings = "GestureMappings"
        static let avoidSystemGestureConflicts = "AvoidSystemGestureConflicts"
        static let gestureConfiguration = "GestureConfiguration"
        static let didShowWelcome = "DidShowPermissionsOnFirstLaunch"

        static func browserEnabled(_ browser: Browser) -> String {
            "\(browser.settingsName)Enabled"
        }
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder.outputFormatting = [.sortedKeys]

        var registered: [String: Any] = [
            Key.enabled: true,
            Key.launchAtLogin: false,
            Key.avoidSystemGestureConflicts: true,
            Key.didShowWelcome: false,
        ]
        for browser in Browser.allCases {
            registered[Key.browserEnabled(browser)] = true
        }
        defaults.register(defaults: registered)
    }

    // MARK: - General

    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { set(newValue, forKey: Key.enabled) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin) }
        set { set(newValue, forKey: Key.launchAtLogin) }
    }

    var avoidsSystemGestureConflicts: Bool {
        get { defaults.bool(forKey: Key.avoidSystemGestureConflicts) }
        set { set(newValue, forKey: Key.avoidSystemGestureConflicts) }
    }

    var didShowWelcome: Bool {
        get { defaults.bool(forKey: Key.didShowWelcome) }
        set { defaults.set(newValue, forKey: Key.didShowWelcome) }
    }

    // MARK: - Browsers

    func isBrowserEnabled(_ browser: Browser) -> Bool {
        defaults.bool(forKey: Key.browserEnabled(browser))
    }

    func setBrowser(_ browser: Browser, enabled: Bool) {
        set(enabled, forKey: Key.browserEnabled(browser))
    }

    // MARK: - Gestures

    var gestureMapping: GestureMapping {
        get {
            guard let data = defaults.data(forKey: Key.gestureMappings) else { return .defaults }
            do {
                return try decoder.decode(GestureMapping.self, from: data)
            } catch {
                Log.settings.error("invalid GestureMappings, using defaults: \(error.localizedDescription, privacy: .public)")
                return .defaults
            }
        }
        set {
            guard let data = try? encoder.encode(newValue) else { return }
            set(data, forKey: Key.gestureMappings)
        }
    }

    var gestureConfiguration: GestureConfiguration {
        get {
            guard let data = defaults.data(forKey: Key.gestureConfiguration),
                  let configuration = try? decoder.decode(GestureConfiguration.self, from: data) else {
                return .default
            }
            return configuration
        }
        set {
            // Store only the values that differ from the defaults, so improved defaults
            // in later versions still reach thresholds the user never changed.
            guard let changed = Self.changedValues(of: newValue, encoder: encoder) else { return }
            if changed.isEmpty {
                remove(Key.gestureConfiguration)
            } else if let data = try? JSONSerialization.data(withJSONObject: changed, options: [.sortedKeys]) {
                set(data, forKey: Key.gestureConfiguration)
            }
        }
    }

    private static func changedValues(of configuration: GestureConfiguration, encoder: JSONEncoder) -> [String: Any]? {
        guard let data = try? encoder.encode(configuration),
              let defaultData = try? encoder.encode(GestureConfiguration.default),
              var values = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let defaultValues = (try? JSONSerialization.jsonObject(with: defaultData)) as? [String: Any] else {
            return nil
        }
        for (key, value) in defaultValues where (values[key] as? NSObject)?.isEqual(value) == true {
            values.removeValue(forKey: key)
        }
        return values
    }

    func resetGestureMapping() {
        remove(Key.gestureMappings)
    }

    func resetGestureConfiguration() {
        remove(Key.gestureConfiguration)
    }

    // MARK: - Storage

    private func set(_ value: Any, forKey key: String) {
        objectWillChange.send()
        defaults.set(value, forKey: key)
        Log.settings.info("setting changed: \(key, privacy: .public)")
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    private func remove(_ key: String) {
        objectWillChange.send()
        defaults.removeObject(forKey: key)
        Log.settings.info("setting reset: \(key, privacy: .public)")
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
