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
/// Only window owners and bounds are read from the window list — never window
/// titles or contents.
final class CGPointerEventSender: PointerEventSending {
    private let postingQueue = DispatchQueue(label: "com.rex0220.rexTrackpad.pointer", qos: .userInteractive)

    func isPointerOverWindow(ofProcess processIdentifier: pid_t) -> Bool {
        guard let location = CGEvent(source: nil)?.location,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return false }

        // The list is ordered front to back; the first visible window under the
        // pointer is the one a click would reach.
        for window in windows {
            guard let boundsInfo = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo),
                  bounds.contains(location) else { continue }
            if let alpha = (window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue, alpha <= 0 {
                continue
            }
            let owner = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
            return owner == processIdentifier
        }
        return false
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
