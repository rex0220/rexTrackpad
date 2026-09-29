import Carbon
import CoreGraphics
import Foundation

protocol KeyCodeResolving {
    /// The virtual key code that types `character` (unshifted) on the active layout.
    func keyCode(for character: Character) -> CGKeyCode?
}

/// Finds key codes by asking the current ASCII-capable keyboard layout which key
/// produces a character. This makes ⌘[ work on a JIS keyboard, where the "[" key is
/// not at the ANSI position.
final class KeyboardLayoutResolver: KeyCodeResolving {
    private var cache: [Character: CGKeyCode] = [:]
    private var cachedLayoutID: String?

    func keyCode(for character: Character) -> CGKeyCode? {
        let target = Character(String(character).lowercased())

        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return KeyCode.ansiFallback[target]
        }

        let layoutID = Self.stringProperty(source, kTISPropertyInputSourceID)
        if layoutID != cachedLayoutID {
            cache.removeAll()
            cachedLayoutID = layoutID
        }
        if let cached = cache[target] {
            return cached
        }

        let resolved = Self.search(source: source, for: target) ?? KeyCode.ansiFallback[target]
        if let resolved {
            cache[target] = resolved
        }
        return resolved
    }

    private static func search(source: TISInputSource, for character: Character) -> CGKeyCode? {
        guard let rawLayout = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(rawLayout).takeUnretainedValue() as Data
        let wanted = String(character)
        let keyboardType = UInt32(LMGetKbdType())

        return layoutData.withUnsafeBytes { buffer -> CGKeyCode? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            for code in 0..<128 {
                var deadKeyState: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout,
                    UInt16(code),
                    UInt16(kUCKeyActionDown),
                    0,
                    keyboardType,
                    OptionBits(kUCKeyTranslateNoDeadKeysMask),
                    &deadKeyState,
                    characters.count,
                    &length,
                    &characters
                )
                if status == noErr, length > 0,
                   String(utf16CodeUnits: characters, count: length) == wanted {
                    return CGKeyCode(code)
                }
            }
            return nil
        }
    }

    private static func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
    }
}
