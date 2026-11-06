import AppKit
import Carbon.HIToolbox
import ChronobarCore

/// A key-down as the Panel's key equivalents see it.
extension PanelKey.Key {
    /// The arrows by key code, anything else by its character ignoring modifiers.
    init?(_ event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_LeftArrow: self = .leftArrow
        case kVK_RightArrow: self = .rightArrow
        default:
            guard let characters = event.charactersIgnoringModifiers else { return nil }
            self = .character(characters)
        }
    }
}

extension PanelKey.Modifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.command) { insert(.command) }
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.control) { insert(.control) }
    }
}
