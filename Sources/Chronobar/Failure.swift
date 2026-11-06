import AppKit
import os

/// Logs a failed action under `category` and beeps, or only logs where a beep would mean nothing (at quit,
/// or at launch before the user has done anything).
@MainActor
func reportFailure(_ error: any Error, category: String, beep: Bool = true) {
    Logger(subsystem: "Chronobar", category: category).error("\(error, privacy: .public)")
    if beep { NSSound.beep() }
}
