import Foundation

protocol PermissionChecking: AnyObject {
    /// Whether synthetic keyboard events will be delivered (Accessibility).
    var canPostKeyboardEvents: Bool { get }
}

/// Result of handling one gesture. Returned mainly for tests and logging.
enum DispatchOutcome: Equatable {
    case disabled
    case unmapped
    case noFrontmostApplication
    case notABrowser(bundleIdentifier: String?)
    case browserDisabled(Browser)
    case noCommand(Browser, BrowserAction)
    case permissionMissing
    /// A click action while the pointer is not over the browser's window.
    case pointerNotOverBrowser(Browser)
    case debounced
    case sendFailed
    case sent(Browser, BrowserAction, BrowserCommand)
}

/// Gesture → GestureAction → (BrowserAction → BrowserCommandResolver) → keyboard / pointer event.
///
/// Main thread only.
final class ActionDispatcher {
    /// Second line of defence against double firing, across all devices.
    var minimumInterval: TimeInterval = 0.2

    private let settings: SettingsStore
    private let browserDetector: BrowserDetecting
    private let commandResolver: BrowserCommandResolver
    private let keyboard: KeyboardEventSending
    private let pointer: PointerEventSending
    private let permissions: PermissionChecking
    private let clock: () -> TimeInterval
    private var lastDispatchTime: TimeInterval = -.infinity

    init(
        settings: SettingsStore,
        browserDetector: BrowserDetecting,
        commandResolver: BrowserCommandResolver = .standard,
        keyboard: KeyboardEventSending,
        pointer: PointerEventSending,
        permissions: PermissionChecking,
        clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.settings = settings
        self.browserDetector = browserDetector
        self.commandResolver = commandResolver
        self.keyboard = keyboard
        self.pointer = pointer
        self.permissions = permissions
        self.clock = clock
    }

    @discardableResult
    func dispatch(_ gesture: TrackpadGesture) -> DispatchOutcome {
        guard settings.isEnabled else {
            return .disabled
        }
        guard let action = settings.gestureMapping.action(for: gesture) else {
            Log.action.info("no action bound to \(gesture.identifier, privacy: .public)")
            return .unmapped
        }

        switch action {
        case .browser(let browserAction):
            return performBrowserAction(browserAction)
        }
    }

    private func performBrowserAction(_ action: BrowserAction) -> DispatchOutcome {
        guard let app = browserDetector.frontmostApplication() else {
            Log.browser.info("browser ignored: no frontmost application")
            return .noFrontmostApplication
        }
        let bundleID = app.bundleIdentifier ?? "(none)"
        Log.browser.info("frontmost application: \(app.name ?? "?", privacy: .public) bundle identifier: \(bundleID, privacy: .public)")

        guard let browser = browserDetector.browser(for: app) else {
            Log.browser.info("browser ignored: \(bundleID, privacy: .public) is not a supported browser")
            return .notABrowser(bundleIdentifier: app.bundleIdentifier)
        }
        guard settings.isBrowserEnabled(browser) else {
            Log.browser.info("browser ignored: \(browser.displayName, privacy: .public) is disabled in settings")
            return .browserDisabled(browser)
        }
        Log.browser.info("browser matched: \(browser.displayName, privacy: .public)")

        guard let command = commandResolver.command(for: action, in: browser) else {
            Log.action.error("no command for \(action.rawValue, privacy: .public) in \(browser.displayName, privacy: .public)")
            return .noCommand(browser, action)
        }
        guard permissions.canPostKeyboardEvents else {
            Log.permission.error("permission missing: Accessibility is required to send \(command.description, privacy: .public)")
            return .permissionMissing
        }
        if case .click = command, !pointer.isPointerOverWindow(ofProcess: app.processIdentifier) {
            Log.action.info("pointer is not over \(browser.displayName, privacy: .public); click not sent")
            return .pointerNotOverBrowser(browser)
        }

        let now = clock()
        guard now - lastDispatchTime >= minimumInterval else {
            Log.action.info("debounce ignored: \(action.rawValue, privacy: .public)")
            return .debounced
        }
        lastDispatchTime = now

        Log.action.info("browser action: \(action.rawValue, privacy: .public) → \(command.description, privacy: .public)")
        let sent: Bool
        switch command {
        case .shortcut(let shortcut): sent = keyboard.send(shortcut)
        case .click(let modifiers): sent = pointer.click(with: modifiers)
        }
        guard sent else {
            return .sendFailed
        }
        return .sent(browser, action, command)
    }
}
