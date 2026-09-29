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
        guard let source = SyntheticEvents.makeSource(),
              let events = SyntheticEvents.keyEvents(for: stroke.eventSequence, source: source) else {
            Log.keyboard.error("failed to create keyboard events")
            return false
        }
        SyntheticEvents.post(events, on: postingQueue)

        Log.keyboard.info("keyboard shortcut sent: \(shortcut.description, privacy: .public) (keyCode \(stroke.keyCode, privacy: .public))")
        return true
    }
}

/// Helpers shared by the keyboard and pointer senders.
enum SyntheticEvents {
    /// Pause between the individual events of one shortcut or click. Posting them in
    /// a single burst lets some apps (Chrome's ⌃Tab) read the modifier state before
    /// the modifier key-down has been applied, so the input is only sometimes honoured.
    static let interEventDelay: TimeInterval = 0.008

    /// The HID system state is what a real keyboard updates, so apps that query the
    /// live modifier state see the synthetic modifier keys too. Flags are set
    /// explicitly on every event, so physically held keys do not leak in.
    static func makeSource() -> CGEventSource? {
        CGEventSource(stateID: .hidSystemState)
    }

    /// Creates every event up front, so a failure can never leave a modifier pressed.
    static func keyEvents(for steps: [KeyEventStep], source: CGEventSource) -> [CGEvent]? {
        var events: [CGEvent] = []
        for step in steps {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: step.keyCode, keyDown: step.keyDown) else {
                return nil
            }
            event.flags = step.flags
            events.append(event)
        }
        return events
    }

    /// Posts `events` in order with `interEventDelay` between them.
    static func post(_ events: [CGEvent], on queue: DispatchQueue) {
        let delay = useconds_t(interEventDelay * 1_000_000)
        queue.async {
            for (index, event) in events.enumerated() {
                if index > 0 { usleep(delay) }
                event.post(tap: .cghidEventTap)
            }
        }
    }
}
