import AppKit
import SwiftUI

/// Shows SwiftUI content in standalone windows (one per id) for a menu-bar-only app.
final class WindowPresenter {
    private var windows: [String: NSWindow] = [:]

    /// `content` receives an action that closes the window, for a Close button.
    func show<Content: View>(id: String, title: String, @ViewBuilder content: (_ close: @escaping () -> Void) -> Content) {
        let close: () -> Void = { [weak self] in self?.windows[id]?.close() }
        // Rebuild the content each time so a reopened window shows fresh state.
        let hosting = NSHostingController(rootView: content(close))

        let window: NSWindow
        if let existing = windows[id] {
            window = existing
            window.contentViewController = hosting
        } else {
            window = NSWindow(contentViewController: hosting)
            window.title = title
            // Settings-style window: closable, but no minimise / zoom buttons.
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            windows[id] = window
        }

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window.makeKeyAndOrderFront(nil)
    }
}
