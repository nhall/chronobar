// KeyboardShortcuts 1.15 predates Swift 6 concurrency checking: `Name` isn't marked Sendable.
@preconcurrency import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Opens the Panel, as a click on the Pill does. No default: the user records one in Settings. Stored
    /// under v1's key, from when it toggled the timer, so a shortcut recorded then still works.
    static let openPanel = Self("toggleTimer")
}
