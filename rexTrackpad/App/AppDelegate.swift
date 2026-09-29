import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests are hosted in the app; don't start monitoring or show UI.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }

        Log.app.notice("rexTrackpad launched")
        let controller = AppController()
        self.controller = controller
        let menuBar = MenuBarController(controller: controller)
        self.menuBar = menuBar
        controller.start()

        if controller.permissions.accessibilityStatus != .granted {
            // The system prompt also adds rexTrackpad to Privacy & Security › Accessibility,
            // so the user only has to flip the switch. Rebuilt (ad-hoc signed) apps need
            // this again because macOS treats every build as a new app.
            controller.permissions.requestAccessibility()

            // First launch: also explain why the permission is needed.
            if !controller.settings.didShowWelcome {
                controller.settings.didShowWelcome = true
                menuBar.showPermissions()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
        Log.app.notice("rexTrackpad terminating")
    }
}
