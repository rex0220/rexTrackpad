import CoreGraphics
import Foundation

protocol KeyboardEventSending {
    /// Posts the shortcut. Returns false if the events could not be created.
    @discardableResult
    func send(_ shortcut: KeyboardShortcut) -> Bool
}

/// Converts a `KeyboardShortcut` into a concrete key code + flags.
struct KeystrokeResolver {
    let keyCodes: KeyCodeResolving

    func resolve(_ shortcut: KeyboardShortcut) -> ResolvedKeystroke? {
        let keyCode: CGKeyCode?
        switch shortcut.key {
        case .character(let character): keyCode = keyCodes.keyCode(for: character)
        case .tab: keyCode = KeyCode.tab
        case .leftArrow: keyCode = KeyCode.leftArrow
        case .rightArrow: keyCode = KeyCode.rightArrow
        case .upArrow: keyCode = KeyCode.upArrow
        case .downArrow: keyCode = KeyCode.downArrow
        }
        guard let keyCode else { return nil }

        var flags = shortcut.modifiers.cgEventFlags
        if shortcut.key.isArrow {
            flags.insert(.maskSecondaryFn)
            flags.insert(.maskNumericPad)
        }
        return ResolvedKeystroke(keyCode: keyCode, flags: flags)
    }
}

/// Posts synthetic key events with Core Graphics.
///
/// Requires the Accessibility permission; without it macOS silently drops the
/// events (callers check permission first and log instead).
final class CGKeyboardEventSender: KeyboardEventSending {
    /// Pause between the individual key events of one shortcut. Posting them in a
    /// single burst lets some apps (Chrome's ⌃Tab) read the modifier state before the
    /// modifier key-down has been applied, so the shortcut is only sometimes honoured.
    static let interEventDelay: TimeInterval = 0.008

    private let resolver: KeystrokeResolver
    /// Events are posted here so the pauses never block the main thread.
    private let postingQueue = DispatchQueue(label: "com.rex0220.rexTrackpad.keyboard", qos: .userInteractive)

    init(keyCodes: KeyCodeResolving = KeyboardLayoutResolver()) {
        self.resolver = KeystrokeResolver(keyCodes: keyCodes)
    }

    @discardableResult
    func send(_ shortcut: KeyboardShortcut) -> Bool {
        // Layout lookup uses Text Input Sources, so resolve on the caller's (main) thread.
        guard let stroke = resolver.resolve(shortcut) else {
            Log.keyboard.error("no key code for shortcut \(shortcut.description, privacy: .public)")
            return false
        }
        // The HID system state is what a real keyboard updates, so apps that query the
        // live modifier state see the synthetic modifier keys too. Flags are set
        // explicitly on every event, so physically held keys do not leak in.
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            Log.keyboard.error("failed to create keyboard event source")
            return false
        }
        // Create every event before posting any, so a failure can never leave a
        // modifier key pressed.
        var events: [CGEvent] = []
        for step in stroke.eventSequence {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: step.keyCode, keyDown: step.keyDown) else {
                Log.keyboard.error("failed to create keyboard events")
                return false
            }
            event.flags = step.flags
            events.append(event)
        }

        let delay = useconds_t(Self.interEventDelay * 1_000_000)
        postingQueue.async {
            for (index, event) in events.enumerated() {
                if index > 0 { usleep(delay) }
                event.post(tap: .cghidEventTap)
            }
        }

        Log.keyboard.info("keyboard shortcut sent: \(shortcut.description, privacy: .public) (keyCode \(stroke.keyCode, privacy: .public))")
        return true
    }
}
