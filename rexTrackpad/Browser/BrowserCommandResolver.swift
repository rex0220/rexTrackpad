import Foundation

/// Supplies the keyboard shortcut a particular browser uses for each action.
protocol BrowserCommandProvider {
    func shortcut(for action: BrowserAction) -> KeyboardShortcut?
}

/// Shortcuts shared by every supported macOS browser.
private enum CommonShortcuts {
    static let reload = KeyboardShortcut(.character("r"), [.command])
    static let newTab = KeyboardShortcut(.character("t"), [.command])
    static let closeTab = KeyboardShortcut(.character("w"), [.command])
    // ⌘[ / ⌘] are documented by Chrome, Edge, Safari and Firefox. The bracket keys sit in
    // different places on JIS / ISO / non-QWERTY layouts, which is why `.character` keys are
    // resolved against the active keyboard layout when sent.
    static let back = KeyboardShortcut(.character("["), [.command])
    static let forward = KeyboardShortcut(.character("]"), [.command])
}

/// Google Chrome, Microsoft Edge and other Chromium browsers.
struct ChromiumCommandProvider: BrowserCommandProvider {
    func shortcut(for action: BrowserAction) -> KeyboardShortcut? {
        switch action {
        case .reload: return CommonShortcuts.reload
        case .hardReload: return KeyboardShortcut(.character("r"), [.command, .shift])
        // ⌃Tab / ⌃⇧Tab: layout-independent and not affected by text-field focus.
        case .nextTab: return KeyboardShortcut(.tab, [.control])
        case .previousTab: return KeyboardShortcut(.tab, [.control, .shift])
        case .newTab: return CommonShortcuts.newTab
        case .closeTab: return CommonShortcuts.closeTab
        case .back: return CommonShortcuts.back
        case .forward: return CommonShortcuts.forward
        }
    }
}

/// Safari. "Reload Page From Origin" is ⌥⌘R, unlike Chromium/Firefox.
struct SafariCommandProvider: BrowserCommandProvider {
    func shortcut(for action: BrowserAction) -> KeyboardShortcut? {
        switch action {
        case .reload: return CommonShortcuts.reload
        case .hardReload: return KeyboardShortcut(.character("r"), [.command, .option])
        case .nextTab: return KeyboardShortcut(.tab, [.control])
        case .previousTab: return KeyboardShortcut(.tab, [.control, .shift])
        case .newTab: return CommonShortcuts.newTab
        case .closeTab: return CommonShortcuts.closeTab
        case .back: return CommonShortcuts.back
        case .forward: return CommonShortcuts.forward
        }
    }
}

/// Firefox. ⌃Tab can be configured to cycle tabs in recently-used order, so the
/// strictly positional ⌥⌘→ / ⌥⌘← are used for tab switching.
struct FirefoxCommandProvider: BrowserCommandProvider {
    func shortcut(for action: BrowserAction) -> KeyboardShortcut? {
        switch action {
        case .reload: return CommonShortcuts.reload
        case .hardReload: return KeyboardShortcut(.character("r"), [.command, .shift])
        case .nextTab: return KeyboardShortcut(.rightArrow, [.command, .option])
        case .previousTab: return KeyboardShortcut(.leftArrow, [.command, .option])
        case .newTab: return CommonShortcuts.newTab
        case .closeTab: return CommonShortcuts.closeTab
        case .back: return CommonShortcuts.back
        case .forward: return CommonShortcuts.forward
        }
    }
}

/// Maps (browser, action) to a keyboard shortcut.
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

    func shortcut(for action: BrowserAction, in browser: Browser) -> KeyboardShortcut? {
        providers[browser]?.shortcut(for: action)
    }
}
