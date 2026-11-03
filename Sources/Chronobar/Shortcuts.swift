// KeyboardShortcuts 1.15 predates Swift 6 concurrency checking: `Name` isn't marked Sendable.
@preconcurrency import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Mirrors the Pill's ▶/⏸ square. No default: the user records one in Settings.
    static let toggleTimer = Self("toggleTimer")
}
