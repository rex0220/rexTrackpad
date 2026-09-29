import Foundation

/// What rexTrackpad sends to a browser to perform an action.
enum BrowserCommand: Hashable, Sendable, CustomStringConvertible {
    /// A keyboard shortcut, e.g. ⌘R.
    case shortcut(KeyboardShortcut)
    /// A click at the mouse pointer with modifier keys held, e.g. ⌘⇧-click on a link.
    case click(KeyboardModifiers)

    var description: String {
        switch self {
        case .shortcut(let shortcut): return shortcut.description
        case .click(let modifiers): return modifiers.symbols + "click"
        }
    }
}

/// Supplies the command a particular browser uses for each action.
protocol BrowserCommandProvider {
    func command(for action: BrowserAction) -> BrowserCommand?
}

/// Commands shared by every supported macOS browser.
private enum CommonCommands {
    static let reload = BrowserCommand.shortcut(KeyboardShortcut(.character("r"), [.command]))
    static let newTab = BrowserCommand.shortcut(KeyboardShortcut(.character("t"), [.command]))
    static let closeTab = BrowserCommand.shortcut(KeyboardShortcut(.character("w"), [.command]))
    static let reopenClosedTab = BrowserCommand.shortcut(KeyboardShortcut(.character("t"), [.command, .shift]))
    // ⌘[ / ⌘] are documented by Chrome, Edge, Safari and Firefox. The bracket keys sit in
    // different places on JIS / ISO / non-QWERTY layouts, which is why `.character` keys are
    // resolved against the active keyboard layout when sent.
    static let back = BrowserCommand.shortcut(KeyboardShortcut(.character("["), [.command]))
    static let forward = BrowserCommand.shortcut(KeyboardShortcut(.character("]"), [.command]))
    // ⌘⇧-click opens a link in a new tab and switches to it in all four browsers.
    static let openLinkInNewTab = BrowserCommand.click([.command, .shift])
}

/// Google Chrome, Microsoft Edge and other Chromium browsers.
struct ChromiumCommandProvider: BrowserCommandProvider {
    func command(for action: BrowserAction) -> BrowserCommand? {
        switch action {
        case .reload: return CommonCommands.reload
        case .hardReload: return .shortcut(KeyboardShortcut(.character("r"), [.command, .shift]))
        // ⌃Tab / ⌃⇧Tab: layout-independent and not affected by text-field focus.
        case .nextTab: return .shortcut(KeyboardShortcut(.tab, [.control]))
        case .previousTab: return .shortcut(KeyboardShortcut(.tab, [.control, .shift]))
        case .newTab: return CommonCommands.newTab
        case .closeTab: return CommonCommands.closeTab
        case .reopenClosedTab: return CommonCommands.reopenClosedTab
        case .back: return CommonCommands.back
        case .forward: return CommonCommands.forward
        case .openLinkInNewTab: return CommonCommands.openLinkInNewTab
        }
    }
}

/// Safari. "Reload Page From Origin" is ⌥⌘R, unlike Chromium/Firefox.
struct SafariCommandProvider: BrowserCommandProvider {
    func command(for action: BrowserAction) -> BrowserCommand? {
        switch action {
        case .reload: return CommonCommands.reload
        case .hardReload: return .shortcut(KeyboardShortcut(.character("r"), [.command, .option]))
        case .nextTab: return .shortcut(KeyboardShortcut(.tab, [.control]))
        case .previousTab: return .shortcut(KeyboardShortcut(.tab, [.control, .shift]))
        case .newTab: return CommonCommands.newTab
        case .closeTab: return CommonCommands.closeTab
        case .reopenClosedTab: return CommonCommands.reopenClosedTab
        case .back: return CommonCommands.back
        case .forward: return CommonCommands.forward
        case .openLinkInNewTab: return CommonCommands.openLinkInNewTab
        }
    }
}

/// Firefox. ⌃Tab can be configured to cycle tabs in recently-used order, so the
/// strictly positional ⌥⌘→ / ⌥⌘← are used for tab switching.
struct FirefoxCommandProvider: BrowserCommandProvider {
    func command(for action: BrowserAction) -> BrowserCommand? {
        switch action {
        case .reload: return CommonCommands.reload
        case .hardReload: return .shortcut(KeyboardShortcut(.character("r"), [.command, .shift]))
        case .nextTab: return .shortcut(KeyboardShortcut(.rightArrow, [.command, .option]))
        case .previousTab: return .shortcut(KeyboardShortcut(.leftArrow, [.command, .option]))
        case .newTab: return CommonCommands.newTab
        case .closeTab: return CommonCommands.closeTab
        case .reopenClosedTab: return CommonCommands.reopenClosedTab
        case .back: return CommonCommands.back
        case .forward: return CommonCommands.forward
        case .openLinkInNewTab: return CommonCommands.openLinkInNewTab
        }
    }
}

/// Maps (browser, action) to the command to send.
struct BrowserCommandResolver {
    private let providers: [Browser: BrowserCommandProvider]

    init(providers: [Browser: BrowserCommandProvider]) {
        self.providers = providers
    }

    static let standard = BrowserCommandResolver(providers: [
        .chrome: ChromiumCommandProvider(),
        .edge: ChromiumCommandProvider(),
        .safari: SafariCommandProvider(),
        .firefox: FirefoxCommandProvider(),
    ])

    func command(for action: BrowserAction, in browser: Browser) -> BrowserCommand? {
        providers[browser]?.command(for: action)
    }
}
