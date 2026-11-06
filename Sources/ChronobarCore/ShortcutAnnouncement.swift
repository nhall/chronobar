import Foundation

/// What VoiceOver announces after the global shortcut. The shortcut acts without moving VoiceOver's
/// attention anywhere, so without an announcement a VoiceOver user can't tell that it did anything.
public enum ShortcutAnnouncement {
    /// The announcement for the shortcut's `action`, given the timers running before it (`before`) and
    /// `tracker` after it: "Paused Website Redesign", "Paused 2 timers", or "New Project" when the ＋ form
    /// opens. Nil when no timer stopped.
    @MainActor
    public static func text(for action: PillClick, before: RunningTimers, after tracker: Tracker) -> String? {
        if action == .openNewProjectForm { return "New Project" }
        let paused = before.filter { !tracker.timers.contains($0.project) }
        return switch paused.count {
        case 0: nil
        case 1: "Paused \(paused[0].project)"
        case let count: "Paused \(count) timers"
        }
    }
}
