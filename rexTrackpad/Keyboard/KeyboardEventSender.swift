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

    init(keyCodes: KeyCodeResolving = KeyboardLayoutResolver()) {
        self.resolver = KeystrokeResolver(keyCodes: keyCodes)
    }

    @discardableResult
    func send(_ shortcut: KeyboardShortcut) -> Bool {
        guard let stroke = resolver.resolve(shortcut) else {
            Log.keyboard.error("no key code for shortcut \(shortcut.description, privacy: .public)")
            return false
        }
        // A private event source keeps physically held modifiers from leaking in.
        guard let source = CGEventSource(stateID: .privateState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: false) else {
            Log.keyboard.error("failed to create keyboard events")
            return false
        }
        keyDown.flags = stroke.flags
        keyUp.flags = stroke.flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        Log.keyboard.info("keyboard shortcut sent: \(shortcut.description, privacy: .public) (keyCode \(stroke.keyCode, privacy: .public))")
        return true
    }
}
