import Foundation

/// What VoiceOver announces after the global shortcut. The shortcut works from any app, so without an
/// announcement a VoiceOver user can't tell that it did anything.
public enum ShortcutAnnouncement {
    /// The shortcut opens the Panel: "Panel opened. 2 timers running, 1 hour today", with what the Pill
    /// reads after it (`PillAccessibility`).
    @MainActor
    public static func text(tracker: Tracker) -> String {
        "Panel opened. \(PillAccessibility(tracker: tracker).label)"
    }
}
