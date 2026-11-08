import AppKit
import CoreGraphics
import ChronobarCore

/// Reports sleep, wake, screen lock and unlock and input inactivity to Core, and shows the idle alert when
/// Core has a question. Core decides when and about what to ask; `Tracker.resolveIdle` takes the answer.
@MainActor
final class IdleMonitor {
    private let tracker: Tracker
    private let resolved: () -> Void
    /// Whether an `ask()` is waiting for the next turn of the run loop.
    private var askScheduled = false
    private var observers: [NSObjectProtocol] = []

    /// `resolved` runs after each answer so the caller can redraw.
    init(tracker: Tracker, resolved: @escaping () -> Void) {
        self.tracker = tracker
        self.resolved = resolved
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification) { $0.tracker.reportAway() }
        observe(workspace, NSWorkspace.didWakeNotification) { $0.tracker.reportBack(); $0.scheduleAsk() }
        // Undocumented but long-standing; posted by loginwindow.
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.tracker.reportAway() }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) {
            $0.tracker.reportBack()
            $0.scheduleAsk()
        }
    }

    /// Called every second. Reports input inactivity while a timer started in the app runs, then asks
    /// whatever Core has a question about (reports, or Idle time it holds after a crash or a refused
    /// removal once the Day file parses).
    func poll() {
        if tracker.appTimerRuns {
            let anyInput = CGEventType(rawValue: ~0)!
            tracker.reportInput(
                idleFor: CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput))
        }
        scheduleAsk()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         _ handle: @escaping @MainActor @Sendable (IdleMonitor) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let self { handle(self) } }
        }
        observers.append(token)
    }

    /// Asks on the next turn of the run loop, so reports that arrive together (wake and unlock) are folded
    /// into one question.
    private func scheduleAsk() {
        guard !askScheduled else { return }
        askScheduled = true
        Task { @MainActor in
            self.askScheduled = false
            self.ask()
        }
    }

    private func ask() {
        guard let question = tracker.takeIdleQuestion() else { return }
        let (since, until, labels) = (question.since, question.until, question.labels)

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
            // Core holds the Idle time and offers the question again once the file parses.
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
