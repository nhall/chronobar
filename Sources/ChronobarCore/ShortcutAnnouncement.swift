import Foundation

/// What VoiceOver announces after the global shortcut. The shortcut acts without moving VoiceOver's
/// attention anywhere, so without an announcement a VoiceOver user can't tell that it did anything.
public enum ShortcutAnnouncement {
    /// The announcement for the shortcut's `action`, given the timer running before it (`before`) and
    /// `tracker` after it: "Started Website Redesign", "Paused Website Redesign", or "New Project" when
    /// the ＋ form opens. Nil when the timer didn't change, as when Core refused the start.
    @MainActor
    public static func text(for action: PillClick, before: Running?, after tracker: Tracker) -> String? {
        if action == .openNewProjectForm { return "New Project" }
        if let running = tracker.running, running != before { return "Started \(running.project)" }
        if let before, tracker.running == nil { return "Paused \(before.project)" }
        return nil
    }
}
