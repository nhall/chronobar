import AppKit
import CoreGraphics
import ChronobarCore
import os

/// Turns sleep, screen lock and input inactivity into the idle alert while a timer runs. Its only logic is
/// deciding the idle start; `Tracker.resolveIdle` does the rest.
@MainActor
final class IdleMonitor {
    private let tracker: Tracker
    private let preferences: Preferences
    private let resolved: () -> Void
    /// When the Mac went to sleep or locked with a timer running, until it wakes or unlocks.
    private var awaySince: Date?
    /// The earliest idle start reported since the alert was scheduled.
    private var pendingSince: Date?
    private var showing = false
    private var observers: [NSObjectProtocol] = []

    /// `resolved` runs after each answer so the caller can redraw.
    init(tracker: Tracker, preferences: Preferences, resolved: @escaping () -> Void) {
        self.tracker = tracker
        self.preferences = preferences
        self.resolved = resolved
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification) { $0.away() }
        observe(workspace, NSWorkspace.didWakeNotification) { $0.back() }
        // Undocumented but long-standing; posted by loginwindow.
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.away() }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.back() }
    }

    /// Called every second. Polls input idle only while a timer runs.
    func poll() {
        guard tracker.running != nil, preferences.detectsInputIdle else { return }
        let anyInput = CGEventType(rawValue: ~0)!
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        guard idle >= TimeInterval(preferences.idleThresholdMinutes * 60) else { return }
        prompt(since: tracker.now - idle)
    }

    /// Asks about the time since `since`, e.g. since the app was last alive before a crash.
    func report(since: Date) {
        prompt(since: since)
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         _ handle: @escaping @MainActor @Sendable (IdleMonitor) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let self { handle(self) } }
        }
        observers.append(token)
    }

    private func away() {
        guard tracker.running != nil else { return }
        // Lock then sleep (or the reverse) keeps the earlier start.
        awaySince = min(awaySince ?? Date(), Date())
    }

    private func back() {
        guard let since = awaySince else { return }
        awaySince = nil
        prompt(since: since)
    }

    /// Schedules the alert, folding reports that arrive together (wake, unlock, input) into the earliest.
    private func prompt(since: Date) {
        guard tracker.running != nil, !showing else { return }
        let scheduled = pendingSince != nil
        pendingSince = min(pendingSince ?? since, since)
        if !scheduled { Task { @MainActor in self.showAlert() } }
    }

    private func showAlert() {
        guard let since = pendingSince else { return }
        pendingSince = nil
        guard let running = tracker.running else { return }
        showing = true
        defer { showing = false }

        let date: Date.FormatStyle.DateStyle = Calendar.current.isDateInToday(since) ? .omitted : .abbreviated
        let alert = NSAlert()
        alert.messageText = "You've been idle since \(since.formatted(date: date, time: .shortened)). "
            + "\(running.project) is still running."
        alert.addButton(withTitle: "Remove idle time")
        alert.addButton(withTitle: "Remove & stop")
        alert.addButton(withTitle: "Keep").keyEquivalent = "\u{1b}"
        NSApp.activate()

        let choice: IdleChoice = switch alert.runModal() {
        case .alertFirstButtonReturn: .remove
        case .alertSecondButtonReturn: .removeAndStop
        default: .keep
        }
        do {
            try tracker.resolveIdle(since: since, choice: choice)
        } catch {
            Logger(subsystem: "Chronobar", category: "idle").error("\(error, privacy: .public)")
            NSSound.beep()
        }
        resolved()
    }
}
