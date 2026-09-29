import AppKit
import Foundation

struct FrontmostApplication: Equatable, Sendable {
    let name: String?
    let bundleIdentifier: String?
    let processIdentifier: pid_t
}

protocol BrowserDetecting {
    func frontmostApplication() -> FrontmostApplication?
    func browser(for application: FrontmostApplication) -> Browser?
}

/// Identifies the frontmost application and whether it is a supported browser.
final class BrowserDetector: BrowserDetecting {
    func frontmostApplication() -> FrontmostApplication? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return FrontmostApplication(
            name: app.localizedName,
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier
        )
    }

    func browser(for application: FrontmostApplication) -> Browser? {
        application.bundleIdentifier.flatMap(Browser.init(bundleIdentifier:))
    }

    /// Whether any channel of the browser is installed (used for menu hints only).
    func isInstalled(_ browser: Browser) -> Bool {
        browser.bundleIdentifiers.contains { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }
}
