import AppKit
import SwiftUI

/// Status-bar icon and menu. The menu is rebuilt each time it opens so it always
/// reflects current settings, permissions and System Settings conflicts.
final class MenuBarController: NSObject, NSMenuDelegate {
    private let controller: AppController
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let windows = WindowPresenter()

    private var settings: SettingsStore { controller.settings }

    init(controller: AppController) {
        self.controller = controller
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        updateIcon()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: SettingsStore.didChangeNotification,
            object: controller.settings
        )
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    // MARK: - Menu construction

    private func rebuildMenu() {
        menu.removeAllItems()

        let header = NSMenuItem(title: "rexTrackpad", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        menu.addItem(makeItem(String(localized: "Enabled"), action: #selector(toggleEnabled), checked: settings.isEnabled))
        menu.addItem(.separator())

        let gestures = NSMenuItem(title: String(localized: "Gestures"), action: nil, keyEquivalent: "")
        gestures.submenu = makeGesturesMenu()
        menu.addItem(gestures)

        let browsers = NSMenuItem(title: String(localized: "Supported Browsers"), action: nil, keyEquivalent: "")
        browsers.submenu = makeBrowsersMenu()
        menu.addItem(browsers)

        menu.addItem(makeLaunchAtLoginItem())
        menu.addItem(.separator())

        let permissionsTitle = controller.permissions.accessibilityStatus == .granted
            ? String(localized: "Permissions…")
            : "⚠︎ " + String(localized: "Permissions…")
        menu.addItem(makeItem(permissionsTitle, action: #selector(showPermissionsAction)))
        menu.addItem(makeItem(String(localized: "Gesture Settings…"), action: #selector(showSettings)))
        #if DEBUG
        menu.addItem(makeItem("Debug Monitor…", action: #selector(showDebugMonitor)))
        #endif
        menu.addItem(.separator())

        menu.addItem(makeItem(String(localized: "About rexTrackpad"), action: #selector(showAbout)))
        menu.addItem(makeItem(String(localized: "Quit"), action: #selector(quit), keyEquivalent: "q"))
    }

    private func makeGesturesMenu() -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let mapping = settings.gestureMapping
        let avoidConflicts = settings.avoidsSystemGestureConflicts

        for gesture in TrackpadGesture.configurable {
            let bound = mapping.action(for: gesture)
            let conflict = controller.activeConflict(for: gesture)

            var title = "\(bound?.displayName ?? String(localized: "None"))  —  \(gesture.displayName)"
            if conflict != nil {
                title += avoidConflicts ? "  " + String(localized: "(off: macOS gesture)") : "  ⚠︎"
            }
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let actions = NSMenu()
            actions.autoenablesItems = false

            if let conflict {
                let info = NSMenuItem(title: String(localized: "Used by macOS: \(conflict.feature.displayName)"), action: nil, keyEquivalent: "")
                info.isEnabled = false
                actions.addItem(info)
                let hint = NSMenuItem(
                    title: avoidConflicts
                        ? String(localized: "Ignored while “Avoid macOS Gesture Conflicts” is on")
                        : String(localized: "Both the macOS gesture and this action will run"),
                    action: nil,
                    keyEquivalent: ""
                )
                hint.isEnabled = false
                actions.addItem(hint)
                actions.addItem(.separator())
            }

            actions.addItem(makeBindingItem(title: String(localized: "None"), gesture: gesture, action: nil, checked: bound == nil))
            for action in GestureAction.allBuiltIn {
                actions.addItem(makeBindingItem(title: action.displayName, gesture: gesture, action: action, checked: bound == action))
            }
            item.submenu = actions
            submenu.addItem(item)
        }

        submenu.addItem(.separator())
        submenu.addItem(makeItem(String(localized: "Avoid macOS Gesture Conflicts"), action: #selector(toggleAvoidConflicts), checked: avoidConflicts))
        submenu.addItem(makeItem(String(localized: "Restore Default Gestures"), action: #selector(restoreDefaultGestures)))
        return submenu
    }

    private func makeBrowsersMenu() -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for browser in Browser.allCases {
            var title = browser.displayName
            if !controller.browserDetector.isInstalled(browser) {
                title = String(localized: "\(browser.displayName) (not installed)")
            }
            let item = makeItem(title, action: #selector(toggleBrowser(_:)), checked: settings.isBrowserEnabled(browser))
            item.representedObject = browser.rawValue
            submenu.addItem(item)
        }
        return submenu
    }

    private func makeLaunchAtLoginItem() -> NSMenuItem {
        let status = controller.loginItems.status
        let item = makeItem(String(localized: "Launch at Login"), action: #selector(toggleLaunchAtLogin))
        switch status {
        case .enabled:
            item.state = .on
        case .requiresApproval:
            item.state = .mixed
            item.title = String(localized: "Launch at Login (approve in System Settings)")
        case .disabled, .notFound:
            item.state = .off
        }
        return item
    }

    private func makeItem(_ title: String, action: Selector, checked: Bool? = nil, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        if let checked {
            item.state = checked ? .on : .off
        }
        return item
    }

    private func makeBindingItem(title: String, gesture: TrackpadGesture, action: GestureAction?, checked: Bool) -> NSMenuItem {
        let item = makeItem(title, action: #selector(selectBinding(_:)), checked: checked)
        item.representedObject = BindingChoice(gesture: gesture, action: action)
        return item
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
    }

    @objc private func selectBinding(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? BindingChoice else { return }
        var mapping = settings.gestureMapping
        mapping.bind(choice.gesture, to: choice.action)
        settings.gestureMapping = mapping
    }

    @objc private func toggleAvoidConflicts() {
        settings.avoidsSystemGestureConflicts.toggle()
    }

    @objc private func restoreDefaultGestures() {
        settings.resetGestureMapping()
    }

    @objc private func toggleBrowser(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let browser = Browser(rawValue: raw) else { return }
        settings.setBrowser(browser, enabled: !settings.isBrowserEnabled(browser))
    }

    @objc private func toggleLaunchAtLogin() {
        let loginItems = controller.loginItems
        switch loginItems.status {
        case .requiresApproval:
            loginItems.openLoginItemsSettings()
            return
        case .enabled, .disabled, .notFound:
            break
        }

        let enable = loginItems.status != .enabled
        do {
            try loginItems.setEnabled(enable)
            settings.launchAtLogin = enable
            if loginItems.status == .requiresApproval {
                loginItems.openLoginItemsSettings()
            }
        } catch {
            Log.app.error("launch at login failed: \(error.localizedDescription, privacy: .public)")
            let alert = NSAlert()
            alert.messageText = String(localized: "Could not change Launch at Login")
            alert.informativeText = error.localizedDescription
            activate()
            alert.runModal()
        }
    }

    @objc private func showPermissionsAction() {
        showPermissions()
    }

    func showPermissions() {
        let model = PermissionsViewModel(permissions: controller.permissions, trackpad: controller.trackpad)
        windows.show(id: "permissions", title: String(localized: "rexTrackpad Permissions")) {
            PermissionsView(model: model)
        }
    }

    @objc private func showSettings() {
        let settings = controller.settings
        windows.show(id: "settings", title: String(localized: "rexTrackpad Gesture Settings")) {
            SettingsView(settings: settings)
        }
    }

    #if DEBUG
    @objc private func showDebugMonitor() {
        let monitor = controller.debugMonitor
        windows.show(id: "debug", title: "rexTrackpad Debug Monitor") {
            DebugMonitorView(monitor: monitor)
        }
    }
    #endif

    @objc private func showAbout() {
        activate()
        let credits = NSAttributedString(
            string: String(localized: "Trackpad gestures for web browsers.") + "\n"
                + "MIT License · https://github.com/rex0220/rexTrackpad\n\n"
                + String(localized: "Uses Apple's private MultitouchSupport.framework to observe touches."),
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "rexTrackpad",
            .credits: credits,
        ])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func settingsDidChange() {
        updateIcon()
    }

    // MARK: - Helpers

    private func updateIcon() {
        let symbol = settings.isEnabled ? "hand.tap" : "hand.raised.slash"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "rexTrackpad")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = settings.isEnabled ? "rexTrackpad" : String(localized: "rexTrackpad (disabled)")
    }

    private func activate() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

/// Payload of a gesture → action menu item.
private final class BindingChoice: NSObject {
    let gesture: TrackpadGesture
    let action: GestureAction?

    init(gesture: TrackpadGesture, action: GestureAction?) {
        self.gesture = gesture
        self.action = action
    }
}
