import AppKit
import Carbon.HIToolbox
import ChronobarCore

extension PanelKey {
    /// What keys type on the keyboard layout selected now, read from the layout itself so that
    /// `PanelKey.command` can ask what a key types with and without each modifier, which an event alone
    /// doesn't tell. Nil when the input source has no layout data.
    static func currentLayout() -> Layout? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        let keyboardType = UInt32(LMGetKbdType())
        return { keyCode, modifiers in
            data.withUnsafeBytes { raw in
                guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return nil }
                var deadKeys: UInt32 = 0
                var characters = [UniChar](repeating: 0, count: 4)
                var length = 0
                let status = UCKeyTranslate(
                    layout, keyCode, UInt16(kUCKeyActionDown), modifiers.carbonKeyState, keyboardType,
                    OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, characters.count, &length, &characters)
                guard status == noErr else { return nil }
                return String(utf16CodeUnits: characters, count: length)
            }
        }
    }
}

extension PanelKey.Modifiers {
    /// Caps Lock is left out: the keys go by the lowercase letter it would capitalize.
    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.command) { insert(.command) }
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.control) { insert(.control) }
    }

    /// The modifiers as `UCKeyTranslate` takes them: Carbon's modifier bits, shifted down a byte.
    var carbonKeyState: UInt32 {
        var keys = 0
        if contains(.command) { keys |= cmdKey }
        if contains(.shift) { keys |= shiftKey }
        if contains(.option) { keys |= optionKey }
        if contains(.control) { keys |= controlKey }
        return UInt32(keys >> 8) & 0xFF
    }
}
