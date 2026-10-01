import AppKit
import CoreGraphics

protocol PointerEventSending {
    /// Whether the frontmost window under the mouse pointer belongs to the process.
    /// Used so a click is only sent into the browser the user is looking at, never
    /// onto the menu bar, the Dock or another app's window.
    func isPointerOverWindow(ofProcess processIdentifier: pid_t) -> Bool

    /// Clicks at the current pointer location with `modifiers` held.
    /// Returns false if the events could not be created.
    @discardableResult
    func click(with modifiers: KeyboardModifiers) -> Bool
}

/// Posts synthetic mouse clicks with Core Graphics (requires Accessibility, like the
/// keyboard sender).
///
/// Only the owner of the window under the pointer is read — never window titles or
/// contents.
final class CGPointerEventSender: PointerEventSending {
    private let postingQueue = DispatchQueue(label: "com.rex0220.rexTrackpad.pointer", qos: .userInteractive)

    /// Main thread only (AppKit).
    func isPointerOverWindow(ofProcess processIdentifier: pid_t) -> Bool {
        // Ask the window server which window a click would reach. Comparing window
        // bounds instead is not enough: Notification Center keeps a transparent,
        // click-through window over the whole screen, and it would always be "on top".
        let number = NSWindow.windowNumber(at: NSEvent.mouseLocation, belowWindowWithWindowNumber: 0)
        guard number > 0,
              let info = CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(number)) as? [[String: Any]],
              let owner = (info.first?[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value else { return false }
        return owner == processIdentifier
    }

    @discardableResult
    func click(with modifiers: KeyboardModifiers) -> Bool {
        guard let location = CGEvent(source: nil)?.location,
              let source = SyntheticEvents.makeSource() else {
            Log.keyboard.error("failed to create pointer event source")
            return false
        }
        let flags = modifiers.cgEventFlags

        // Same order as a person: modifiers down, click, modifiers up.
        guard let press = SyntheticEvents.keyEvents(for: ModifierKeys.pressSteps(for: flags), source: source),
              let release = SyntheticEvents.keyEvents(for: ModifierKeys.releaseSteps(for: flags), source: source),
              let mouseDown = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: location, mouseButton: .left),
              let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: location, mouseButton: .left) else {
            Log.keyboard.error("failed to create pointer events")
            return false
        }
        for event in [mouseDown, mouseUp] {
            event.flags = flags
            event.setIntegerValueField(.mouseEventClickState, value: 1)
        }
        SyntheticEvents.post(press + [mouseDown, mouseUp] + release, on: postingQueue)

        Log.keyboard.info("pointer click sent: \(modifiers.symbols, privacy: .public)click")
        return true
    }
}
