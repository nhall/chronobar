import AppKit
import ChronobarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var tracker: Tracker!
    private var statusItem: StatusItemController!
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        tracker = Tracker(clock: SystemTimeSource(), storageRoot: Self.storageRoot)
        statusItem = StatusItemController(tracker: tracker)

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // `.common` keeps the Pill ticking while a menu or the popover is tracking events.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        tracker.tick()
        statusItem.refresh()
    }

    /// `~/Library/Application Support/Chronobar`.
    private static var storageRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Chronobar", isDirectory: true)
    }
}
