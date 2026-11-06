import Foundation
import UserNotifications
import ChronobarCore

/// The long-running warning: a notification naming each timer Core reports past the threshold, with a Stop
/// action that stops that run when clicked. Permission is asked the first time one is due; if it is denied
/// nothing is shown and the timers carry on. Never cuts time itself.
@MainActor
final class LongRunningNotifier: NSObject, UNUserNotificationCenterDelegate {
    private let tracker: Tracker
    /// Called after Stop changes the timers, so the Pill and Panel catch up.
    private let changed: () -> Void
    /// nil outside an app bundle (`swift run`), where the notification center can't be used.
    private let center: UNUserNotificationCenter?

    private nonisolated static let category = "longRunning"
    private nonisolated static let stopAction = "stop"

    init(tracker: Tracker, changed: @escaping () -> Void) {
        self.tracker = tracker
        self.changed = changed
        center = Bundle.main.bundleIdentifier == nil ? nil : .current()
        super.init()
        center?.delegate = self
        let stop = UNNotificationAction(identifier: Self.stopAction, title: "Stop", options: [])
        center?.setNotificationCategories([
            UNNotificationCategory(identifier: Self.category, actions: [stop], intentIdentifiers: [], options: []),
        ])
    }

    /// Posts one notification per run, once permission is granted.
    func warn(_ runs: [LongRunning], threshold: LongRunningThreshold) {
        guard let center, !runs.isEmpty, let hours = threshold.hours else { return }
        let requests = runs.map { run in
            let content = UNMutableNotificationContent()
            content.title = "\(run.project) is still running"
            content.body = "Running for over \(hours) hours, since \(Self.time(run.since)). Stop it if it's done."
            content.sound = .default
            content.categoryIdentifier = Self.category
            content.userInfo = ["project": run.project, "since": run.since.timeIntervalSinceReferenceDate]
            let id = "longRunning \(run.project) \(run.since.timeIntervalSinceReferenceDate)"
            return UNNotificationRequest(identifier: id, content: content, trigger: nil)
        }
        Task {
            do {
                guard try await center.requestAuthorization(options: [.alert, .sound]) else { return }
                for request in requests { try await center.add(request) }
            } catch {
                reportFailure(error, category: "long-running", beep: false)
            }
        }
    }

    /// The start time, with its date when it wasn't today.
    private static func time(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(date: .abbreviated, time: .shortened)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == Self.stopAction else { return }
        let info = response.notification.request.content.userInfo
        guard let project = info["project"] as? String, let since = info["since"] as? TimeInterval else { return }
        let run = LongRunning(project: project, since: Date(timeIntervalSinceReferenceDate: since))
        await MainActor.run {
            do {
                try tracker.pause(run)
            } catch {
                reportFailure(error, category: "long-running")
            }
            changed()
        }
    }

    /// Shown even while Chronobar is the frontmost app.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
