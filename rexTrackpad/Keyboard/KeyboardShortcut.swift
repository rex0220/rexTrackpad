import CoreGraphics
import Foundation

/// Modifier keys, independent of Core Graphics.
struct KeyboardModifiers: OptionSet, Hashable, Sendable {
    let rawValue: UInt8

    static let control = KeyboardModifiers(rawValue: 1 << 0)
    static let option = KeyboardModifiers(rawValue: 1 << 1)
    static let shift = KeyboardModifiers(rawValue: 1 << 2)
    static let command = KeyboardModifiers(rawValue: 1 << 3)

    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.control) { flags.insert(.maskControl) }
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.command) { flags.insert(.maskCommand) }
        return flags
    }

    /// macOS menu order: ⌃⌥⇧⌘.
    var symbols: String {
        var text = ""
        if contains(.control) { text += "⌃" }
        if contains(.option) { text += "⌥" }
        if contains(.shift) { text += "⇧" }
        if contains(.command) { text += "⌘" }
        return text
    }
}

/// A key, described by meaning rather than by hardware key code.
enum KeyboardKey: Hashable, Sendable {
    /// A printable character, e.g. "r" or "[". Resolved against the active keyboard
    /// layout at send time, so shortcuts work on JIS, ISO and non-QWERTY layouts.
    case character(Character)
    case tab
    case leftArrow
    case rightArrow
    case upArrow
    case downArrow

    var displayName: String {
        switch self {
        case .character(let character): return String(character).uppercased()
        case .tab: return "⇥"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .upArrow: return "↑"
        case .downArrow: return "↓"
        }
    }

    /// Arrow keys carry the Fn and numeric-pad flags when typed on real hardware;
    /// synthetic events mirror that so apps match them the same way.
    var isArrow: Bool {
        switch self {
        case .leftArrow, .rightArrow, .upArrow, .downArrow: return true
        default: return false
        }
    }
}

/// A key combination such as ⌘R.
struct KeyboardShortcut: Hashable, Sendable, CustomStringConvertible {
    let key: KeyboardKey
    let modifiers: KeyboardModifiers

    init(_ key: KeyboardKey, _ modifiers: KeyboardModifiers) {
        self.key = key
        self.modifiers = modifiers
    }

    var description: String {
        modifiers.symbols + key.displayName
    }
}

/// A shortcut resolved to a concrete virtual key code for the current keyboard layout.
struct ResolvedKeystroke: Equatable, Sendable {
    let keyCode: CGKeyCode
    let flags: CGEventFlags

    /// The key events a person typing this shortcut produces: modifiers down one by
    /// one, the key down and up, then the modifiers up in reverse order.
    ///
    /// Setting flags on the key event alone is not enough: some shortcuts (e.g.
    /// Chrome's ⌃Tab) check the live modifier state, which only changes when the
    /// modifier keys themselves are pressed.
    var eventSequence: [KeyEventStep] {
        ModifierKeys.pressSteps(for: flags)
            + [KeyEventStep(keyCode: keyCode, keyDown: true, flags: flags),
               KeyEventStep(keyCode: keyCode, keyDown: false, flags: flags)]
            + ModifierKeys.releaseSteps(for: flags)
    }
}

/// Pressing and releasing modifier keys the way a person does, shared by keyboard
/// shortcuts and modified clicks.
enum ModifierKeys {
    /// Modifier keys in the order a person presses them (⌃⌥⇧⌘).
    private static let all: [(flag: CGEventFlags, keyCode: CGKeyCode)] = [
        (.maskControl, KeyCode.control),
        (.maskAlternate, KeyCode.option),
        (.maskShift, KeyCode.shift),
        (.maskCommand, KeyCode.command),
    ]

    /// Key-down events for the modifiers in `flags`, one at a time.
    static func pressSteps(for flags: CGEventFlags) -> [KeyEventStep] {
        var held: CGEventFlags = []
        return all.filter { flags.contains($0.flag) }.map { modifier in
            held.insert(modifier.flag)
            return KeyEventStep(keyCode: modifier.keyCode, keyDown: true, flags: held)
        }
    }

    /// Key-up events for the modifiers in `flags`, in reverse order.
    static func releaseSteps(for flags: CGEventFlags) -> [KeyEventStep] {
        var held = flags.intersection([.maskControl, .maskAlternate, .maskShift, .maskCommand])
        return all.reversed().filter { flags.contains($0.flag) }.map { modifier in
            held.remove(modifier.flag)
            return KeyEventStep(keyCode: modifier.keyCode, keyDown: false, flags: held)
        }
    }
}

/// One synthetic key-down or key-up event.
struct KeyEventStep: Equatable, Sendable {
    let keyCode: CGKeyCode
    let keyDown: Bool
    let flags: CGEventFlags
}
