import AppKit
import CoreGraphics
import ChronobarCore

/// Turns sleep, screen lock and input inactivity into the idle alert while a timer started in the app runs.
/// Agents keep working while the user is away, so their timers never raise it. Its only logic is deciding
/// the idle start; `Tracker.resolveIdle` does the rest.
@MainActor
final class IdleMonitor {
    private let tracker: Tracker
    private let preferences: Preferences
    private let resolved: () -> Void
    /// When the Mac went to sleep or locked with a timer running, until it wakes or unlocks.
    private var awaySince: Date?
    /// The earliest idle start reported since the alert was scheduled, and where that Idle time ends
    /// (nil: now).
    private var pendingSince: Date?
    private var pendingUntil: Date?
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

    /// Called every second. Asks about Idle time Core is holding (after a crash, or a removal refused
    /// while a Day file was malformed, once it parses). Polls input idle only while an app timer runs.
    func poll() {
        if let idle = tracker.pendingIdle, idle.blockedBy == nil {
            prompt(since: idle.since, until: idle.until)
        }
        guard !appTimers.isEmpty, let minutes = preferences.idleThreshold.minutes else { return }
        let anyInput = CGEventType(rawValue: ~0)!
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        guard idle >= TimeInterval(minutes * 60) else { return }
        prompt(since: tracker.now - idle)
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         _ handle: @escaping @MainActor @Sendable (IdleMonitor) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let self { handle(self) } }
        }
        observers.append(token)
    }

    /// The running timers started in the app, the only ones idle time applies to.
    private var appTimers: [Running] { tracker.timers.filter { $0.source == .app } }

    private func away() {
        guard !appTimers.isEmpty else { return }
        // Lock then sleep (or the reverse) keeps the earlier start.
        awaySince = min(awaySince ?? Date(), Date())
    }

    private func back() {
        guard let since = awaySince else { return }
        awaySince = nil
        prompt(since: since)
    }

    /// Schedules the alert, folding reports that arrive together (wake, unlock, input, Core's pending Idle
    /// time) into the earliest. Idle time up to now wins over one that ends earlier. Core's pending Idle
    /// time is asked about even with no app timer running: a crash may have left app-started time to cut
    /// in an Entry that recovery closed.
    private func prompt(since: Date, until: Date? = nil) {
        guard !appTimers.isEmpty || tracker.pendingIdle != nil, !showing else { return }
        let scheduled = pendingSince != nil
        pendingUntil = scheduled ? pendingUntil.flatMap { a in until.map { max(a, $0) } } : until
        pendingSince = min(pendingSince ?? since, since)
        if !scheduled { Task { @MainActor in self.showAlert() } }
    }

    private func showAlert() {
        guard let since = pendingSince else { return }
        let until = pendingUntil
        pendingSince = nil
        pendingUntil = nil
        let labels = appTimers.map(\.project)
        guard !labels.isEmpty || tracker.pendingIdle != nil else { return }
        showing = true
        defer { showing = false }

        // One alert for every app timer; each choice applies to all of them.
        let running = labels.formatted(.list(type: .and))
        let verb = labels.count == 1 ? "is" : "are"
        let alert = NSAlert()
        if let until {
            alert.messageText = "You were idle from \(Self.time(since)) to \(Self.time(until))."
                + (labels.isEmpty ? "" : " \(running) \(verb) running.")
        } else {
            alert.messageText = "You've been idle since \(Self.time(since))."
                + (labels.isEmpty ? "" : " \(running) \(verb) still running.")
        }
        alert.addButton(withTitle: "Remove idle time")
        alert.addButton(withTitle: "Remove & stop")
        alert.addButton(withTitle: "Keep").keyEquivalent = "\u{1b}"
        NSApp.comeToFront()

        let choice: IdleChoice = switch alert.runModal() {
        case .alertFirstButtonReturn: .remove
        case .alertSecondButtonReturn: .removeAndStop
        default: .keep
        }
        do {
            try tracker.resolveIdle(since: since, until: until, choice: choice)
        } catch let error as MalformedDayFile {
            // Core keeps the Idle time pending and `poll()` asks again once the file parses.
            resolved()
            refused(error.day)
            return
        } catch {
            reportFailure(error, category: "idle")
        }
        resolved()
    }

    /// Says which Day file stopped the removal.
    private func refused(_ day: Day) {
        let date = day.noon(in: tracker.calendar)
            .formatted(Date.FormatStyle(date: .complete, time: .omitted, calendar: tracker.calendar))
        let alert = NSAlert()
        alert.messageText = "The idle time wasn't removed"
        alert.informativeText = "The file for \(date) (days/\(day).json) can't be read, so it can't be "
            + "changed. Fix it by hand in the data folder and you'll be asked again. Until then the idle "
            + "time still counts."
        NSApp.comeToFront()
        alert.runModal()
    }

    /// "2:10 PM" today, with the date on other Days.
    private static func time(_ date: Date) -> String {
        let style: Date.FormatStyle.DateStyle = Calendar.current.isDateInToday(date) ? .omitted : .abbreviated
        return date.formatted(date: style, time: .shortened)
    }
}
