import Foundation

/// What a gesture does.
///
/// v0.1 only has browser actions. The enum is the extension point for future kinds,
/// which would be added as new cases with their own executor in `ActionDispatcher`:
///
///     case keyboardShortcut(KeyboardShortcut)   // arbitrary shortcut
///     case openURL(URL)
///     case launchApplication(bundleIdentifier: String)
///     case appleScript(source: String)
///     case shellCommand(String)
///     case screenshot
enum GestureAction: Hashable, Sendable {
    case browser(BrowserAction)

    static let allBuiltIn: [GestureAction] = BrowserAction.allCases.map(GestureAction.browser)

    /// Stable string used for persistence, e.g. `browser.reload`.
    var identifier: String {
        switch self {
        case .browser(let action): return "browser.\(action.rawValue)"
        }
    }

    init?(identifier: String) {
        let parts = identifier.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "browser":
            guard let action = BrowserAction(rawValue: parts[1]) else { return nil }
            self = .browser(action)
        default:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .browser(let action): return action.displayName
        }
    }
}

extension GestureAction: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        guard let action = GestureAction(identifier: identifier) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown action '\(identifier)'")
        }
        self = action
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(identifier)
    }
}
