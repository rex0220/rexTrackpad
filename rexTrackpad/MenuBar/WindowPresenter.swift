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
        let isNew: Bool
        if let existing = windows[id] {
            window = existing
            window.contentViewController = hosting
            isNew = false
        } else {
            window = NSWindow(contentViewController: hosting)
            window.title = title
            // Settings-style window: closable, but no minimise / zoom buttons.
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            windows[id] = window
            isNew = true
        }

        // Size the window to its content *before* placing it. Otherwise it is placed at
        // its initial (small) size and then grows upwards under the menu bar.
        hosting.view.layoutSubtreeIfNeeded()
        window.setContentSize(hosting.view.fittingSize)
        place(window, centre: isNew || !window.isVisible)

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window.makeKeyAndOrderFront(nil)

        // SwiftUI may settle the final size a moment later; keep the window on screen.
        DispatchQueue.main.async { [weak self, weak window] in
            guard let window = window else { return }
            self?.place(window, centre: false)
        }
    }

    /// Centres the window in the visible area of the screen with the pointer (below the
    /// menu bar, above the Dock), or just moves it back inside that area.
    private func place(_ window: NSWindow, centre: Bool) {
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = window.frame

        if centre {
            frame.origin.x = visible.midX - frame.width / 2
            frame.origin.y = visible.midY - frame.height / 2
        }
        // Keep the window inside the screen; if it is taller than the screen, the title
        // bar (top) wins and stays below the menu bar.
        frame.origin.y = max(frame.origin.y, visible.minY)
        frame.origin.y = min(frame.origin.y, visible.maxY - frame.height)
        frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)

        if frame != window.frame {
            window.setFrame(frame, display: true)
        }
    }
}
