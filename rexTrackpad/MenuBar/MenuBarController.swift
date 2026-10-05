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

        // On/off switches first.
        menu.addItem(makeItem(String(localized: "Enabled"), action: #selector(toggleEnabled), checked: settings.isEnabled))
        menu.addItem(makeLaunchAtLoginItem())
        menu.addItem(.separator())

        // Gestures, sensitivity, browsers and permissions all live in the settings window.
        menu.addItem(makeItem(String(localized: "Settings…"), action: #selector(showSettingsAction), keyEquivalent: ","))
        if controller.permissions.accessibilityStatus != .granted {
            menu.addItem(makeItem("⚠︎ " + String(localized: "Accessibility Permission Needed…"), action: #selector(showPermissionsAction)))
        }
        menu.addItem(.separator())

        #if DEBUG
        menu.addItem(makeItem("Debug Monitor…", action: #selector(showDebugMonitor)))
        menu.addItem(.separator())
        #endif

        menu.addItem(makeItem(String(localized: "About rexTrackpad"), action: #selector(showAbout)))
        menu.addItem(makeItem(String(localized: "Quit"), action: #selector(quit), keyEquivalent: "q"))
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

    // MARK: - Actions

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
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

    @objc private func showSettingsAction() {
        showSettings(tab: .assignments)
    }

    @objc private func showPermissionsAction() {
        showSettings(tab: .permissions)
    }

    /// Also used on first launch to explain the Accessibility permission.
    func showPermissions() {
        showSettings(tab: .permissions)
    }

    func showSettings(tab: SettingsView.Tab) {
        let controller = self.controller
        let permissions = PermissionsViewModel(permissions: controller.permissions, trackpad: controller.trackpad)
        windows.show(id: "settings", title: String(localized: "rexTrackpad Settings")) { close in
            SettingsView(
                settings: controller.settings,
                conflict: { controller.activeConflict(for: $0) },
                isInstalled: { controller.browserDetector.isInstalled($0) },
                permissions: permissions,
                recentTaps: controller.recentTaps,
                close: close,
                initialTab: tab
            )
        }
    }

    #if DEBUG
    @objc private func showDebugMonitor() {
        let monitor = controller.debugMonitor
        windows.show(id: "debug", title: "rexTrackpad Debug Monitor") { _ in
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
