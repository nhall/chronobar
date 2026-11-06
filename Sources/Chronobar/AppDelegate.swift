import AppKit
import ChronobarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences = Preferences(defaults: .standard)
    let loginItem = LoginItem()
    private var tracker: Tracker!
    private var statusItem: StatusItemController!
    private var idleMonitor: IdleMonitor!
    private var timer: Timer?
    private var heartbeat: Timer?
    /// `nil` when the Info.plist names a bad data folder; the app then refuses to start.
    private var variant: BuildVariant?

    func applicationWillFinishLaunching(_ notification: Notification) {
        do {
            variant = try BuildVariant(info: Bundle.main.infoDictionary)
        } catch {
            reportFailure(error, category: "launch", beep: false)
        }
        // Before launch finishes, so with Show in Dock off the app starts silently in the menu bar.
        applyDockPolicy(launching: true)
        observeShowInDock()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let variant else {
            refuseToStart()
            return
        }
        let storageRoot = variant.storageRoot(
            in: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0])
        // Not in applicationWillFinishLaunching: the Dock tile doesn't keep a badge set before launch finishes.
        showDockBadge()
        loginItem.renew()
        tracker = Tracker(clock: SystemTimeSource(), storageRoot: storageRoot, defaults: .standard)
        statusItem = StatusItemController(
            tracker: tracker, variant: variant, storageRoot: storageRoot, preferences: preferences,
            loginItem: loginItem)
        idleMonitor = IdleMonitor(tracker: tracker, preferences: preferences) { [weak self] in
            self?.statusItem.refresh()
        }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // `.common` keeps the Pill ticking while a menu or the popover is tracking events.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        let heartbeat = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tracker.heartbeat() }
        }
        RunLoop.main.add(heartbeat, forMode: .common)
        self.heartbeat = heartbeat

        // Roll over to the new Day straight away on wake rather than on the next timer fire.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tracker.heartbeat() }
        }

        // An Entry left open by a crash or forced shutdown: ask about the time since the app was last alive.
        // Core keeps it in `pendingIdle`, which the idle monitor asks about.
        tracker.recoverAfterLaunch()
        statusItem.refresh()
        idleMonitor.poll()
    }

    /// Quitting stops the running timer at the quit time.
    func applicationWillTerminate(_ notification: Notification) {
        do {
            try tracker?.pause()
        } catch {
            reportFailure(error, category: "quit", beep: false)
        }
    }

    /// Clicking the Dock icon opens the Panel under the Pill. The reopen request doesn't say whether that
    /// was a click, ⌘-Tab or Full Keyboard Access in the Dock, so the Panel keeps its focus ring.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem?.showPanel(by: .appReopen)
        return false
    }

    private func tick() {
        tracker.tick()
        idleMonitor.poll()
        statusItem.refresh()
    }

    /// `launching` is for the policy the app starts with: leaving the Dock then hides no Settings window, and
    /// coming to the front would take it from whatever the user is doing, as at login.
    private func applyDockPolicy(launching: Bool = false) {
        let policy: NSApplication.ActivationPolicy = preferences.showInDock ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        // The Dock tile is new each time the app enters the Dock, so its badge goes back on.
        if policy == .regular && NSApp.isRunning { showDockBadge() }
        if policy == .accessory && !launching { comeBackAfterLeavingDock() }
    }

    /// Leaving the Dock deactivates the app, which would drop the Settings window behind other apps, so the
    /// app comes back to the front each time it is deactivated in the next `dockLeaveWatch`. Seen on macOS
    /// 27: the app is deactivated straight away, and comes back; about 70 ms later macOS hands the front to
    /// another app again, which deactivates it once more, and it comes back for good. No notification marks
    /// the end of that handover, so the watch ends after a set time.
    private func comeBackAfterLeavingDock() {
        endDockLeave()
        dockLeaveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: NSApp, queue: .main
        ) { _ in
            MainActor.assumeIsolated { NSApp.comeToFront() }
        }
        let watch = Timer(timeInterval: Self.dockLeaveWatch, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.endDockLeave() }
        }
        RunLoop.main.add(watch, forMode: .common)
        dockLeaveTimer = watch
    }

    private func endDockLeave() {
        if let dockLeaveObserver { NotificationCenter.default.removeObserver(dockLeaveObserver) }
        dockLeaveObserver = nil
        dockLeaveTimer?.invalidate()
        dockLeaveTimer = nil
    }

    /// While `comeBackAfterLeavingDock` watches: its observer, and the timer that ends the watch.
    private var dockLeaveObserver: NSObjectProtocol?
    private var dockLeaveTimer: Timer?

    /// How long `comeBackAfterLeavingDock` watches: several times the handover macOS was seen to take.
    private static let dockLeaveWatch: TimeInterval = 0.3

    private func observeShowInDock() {
        withObservationTracking {
            _ = preferences.showInDock
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.applyDockPolicy()
                self?.observeShowInDock()
            }
        }
    }

    /// A development copy labels its Dock icon so manual testing clicks the right copy.
    private func showDockBadge() {
        NSApp.dockTile.badgeLabel = variant?.badge
    }

    /// A bundle whose Info.plist names a bad data folder stops rather than guess at a folder.
    private func refuseToStart() {
        let alert = NSAlert()
        alert.messageText = "Chronobar can't start"
        alert.informativeText =
            "This copy's Info.plist doesn't name a usable data folder (\(BuildVariant.dataFolderKey))."
        alert.runModal()
        NSApp.terminate(nil)
    }
}
