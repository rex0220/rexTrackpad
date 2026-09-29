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

        // First launch: explain which permission is needed instead of surprising the user.
        if !controller.settings.didShowWelcome {
            controller.settings.didShowWelcome = true
            if controller.permissions.accessibilityStatus != .granted {
                menuBar.showPermissions()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
        Log.app.notice("rexTrackpad terminating")
    }
}
