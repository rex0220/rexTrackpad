import Foundation

/// Rendering engine family. Browsers of the same family usually share shortcuts,
/// so new Chromium browsers (Brave, Vivaldi, Opera, Chromium, …) can reuse
/// `ChromiumCommandProvider`.
enum BrowserEngine: Sendable {
    case chromium
    case webKit
    case gecko
}

/// A supported browser.
///
/// To add a browser (e.g. Brave):
/// 1. add a case,
/// 2. fill in `displayName`, `engine`, `bundleIdentifiers` and `settingsName`,
/// 3. register a provider in `BrowserCommandResolver.standard` (often an existing one).
///
/// Candidate bundle identifiers for future versions (verify before use):
/// Brave `com.brave.Browser`, Arc `company.thebrowser.Browser`,
/// Vivaldi `com.vivaldi.Vivaldi`, Opera `com.operasoftware.Opera`,
/// Chromium `org.chromium.Chromium`.
enum Browser: String, CaseIterable, Codable, Sendable {
    case chrome
    case safari
    case edge
    case firefox

    var displayName: String {
        switch self {
        case .chrome: return "Chrome"
        case .safari: return "Safari"
        case .edge: return "Edge"
        case .firefox: return "Firefox"
        }
    }

    var engine: BrowserEngine {
        switch self {
        case .chrome, .edge: return .chromium
        case .safari: return .webKit
        case .firefox: return .gecko
        }
    }

    /// Bundle identifiers of the stable release first, followed by pre-release channels.
    var bundleIdentifiers: [String] {
        switch self {
        case .chrome:
            return ["com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.dev", "com.google.Chrome.canary"]
        case .safari:
            return ["com.apple.Safari", "com.apple.SafariTechnologyPreview"]
        case .edge:
            return ["com.microsoft.edgemac", "com.microsoft.edgemac.Beta", "com.microsoft.edgemac.Dev", "com.microsoft.edgemac.Canary"]
        case .firefox:
            return ["org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.nightly"]
        }
    }

    /// Name used in UserDefaults keys, e.g. `ChromeEnabled`.
    var settingsName: String {
        switch self {
        case .chrome: return "Chrome"
        case .safari: return "Safari"
        case .edge: return "Edge"
        case .firefox: return "Firefox"
        }
    }

    init?(bundleIdentifier: String) {
        guard let match = Browser.allCases.first(where: { $0.bundleIdentifiers.contains(bundleIdentifier) }) else {
            return nil
        }
        self = match
    }
}
