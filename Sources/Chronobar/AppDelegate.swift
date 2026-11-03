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

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Before launch finishes, so with Show in Dock off the app starts silently in the menu bar.
        applyDockPolicy()
        observeShowInDock()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        tracker = Tracker(clock: SystemTimeSource(), storageRoot: Self.storageRoot, defaults: .standard)
        statusItem = StatusItemController(tracker: tracker, preferences: preferences, loginItem: loginItem)
        idleMonitor = IdleMonitor(tracker: tracker, preferences: preferences) { [weak self] in
            self?.statusItem.refresh()
        }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // `.common` keeps the Pill ticking while a menu or the popover is tracking events.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        // Roll over to the new Day straight away on wake rather than on the next timer fire.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    /// Clicking the Dock icon opens the Panel under the Pill.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem?.showPanel()
        return false
    }

    private func tick() {
        tracker.tick()
        idleMonitor.poll()
        statusItem.refresh()
    }

    private func applyDockPolicy() {
        let policy: NSApplication.ActivationPolicy = preferences.showInDock ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        // Leaving the Dock deactivates the app, which would drop the Settings window behind other apps.
        if policy == .accessory && NSApp.isRunning { NSApp.activate() }
    }

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

    /// `~/Library/Application Support/Chronobar`.
    private static var storageRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Chronobar", isDirectory: true)
    }
}
