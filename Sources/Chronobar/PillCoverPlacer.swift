import AppKit
import ChronobarCore

/// Keeps the cover (`PillCover`) over the Pill while the pointer is on it and the Pill is shown there, and
/// away otherwise (`PillCoverArea`): it reads the window list and the window under the Pill, watches for
/// the Pill coming under a resting pointer, and looks again while an auto-hidden menu bar slides in.
@MainActor
final class PillCoverPlacer {
    let cover = PillCover()
    private let statusItem: NSStatusItem
    /// The status item's window that `observe` watches, and its observers' tokens.
    private weak var observedWindow: NSWindow?
    private var windowObservers: [NSObjectProtocol] = []
    /// How many times in a row the cover has looked again for a Pill that wasn't shown yet.
    private var pillChecks = 0
    private var pillCheck: Timer?

    /// How often, and how many times in a row, `checkPillSoon` looks again: about a second in all, as
    /// long as an auto-hidden menu bar takes to slide in.
    private static let pillCheckInterval: TimeInterval = 0.1
    private static let pillCheckLimit = 10

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        observeApp()
        observeStatusItemWindow()
    }

    /// Whether `window` is the cover.
    func isCover(_ window: NSWindow?) -> Bool { window === cover }

    /// Puts the cover up or takes it away. Run on every pointer move, so it follows the status item wherever
    /// it goes, and on every mouse-down. Also run without the pointer moving: on the notifications
    /// `observeApp` and `observeStatusItemWindow` watch, and every second from the app's tick through `StatusItemController.refresh`, so a press on a
    /// Pill that appeared or moved under a resting pointer is covered too. At a mouse-down,
    /// `pressCommandKey` is whether that press had ⌘ held, and the cover can go even from under it.
    func place(pressCommandKey: Bool? = nil) {
        observeStatusItemWindow()
        let duringPress = pressCommandKey != nil
        guard let window = statusItem.button?.window, let (item, screen) = statusItem.frameOnScreen else {
            return cover.remove(duringPress: duringPress)
        }
        let pointer = NSEvent.mouseLocation
        let placement = PillCoverArea.placement(
            item: item, screen: screen.frame, pointer: pointer,
            commandKey: pressCommandKey ?? NSEvent.modifierFlags.contains(.command),
            pressHeld: !duringPress && !cover.isVisible && NSEvent.pressedMouseButtons & 1 != 0,
            menuBars: Self.menuBars(),
            windowAtPill: Self.windowBelowOwnWindows(
                at: CGPoint(x: pointer.x, y: item.midY), pillWindow: window.windowNumber),
            pillWindow: window.windowNumber, coverUp: cover.isVisible)
        switch placement {
        case .cover(let frame):
            cover.place(at: frame)
        case .away:
            cover.remove(duringPress: duringPress)
        case .awaitingPill:
            cover.remove(duringPress: duringPress)
            return checkPillSoon()
        }
        pillChecks = 0
    }

    /// Looks again in a moment for a Pill not shown under a resting pointer yet, such as on an auto-hidden
    /// menu bar sliding in, up to `pillCheckLimit` times; after that, the app's tick still looks once a
    /// second.
    private func checkPillSoon() {
        guard pillCheck == nil, pillChecks < Self.pillCheckLimit else { return }
        pillChecks += 1
        let timer = Timer(timeInterval: Self.pillCheckInterval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pillCheck = nil
                self?.place()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pillCheck = timer
    }

    /// The menu bars on screen now, from the window list.
    private static func menuBars() -> [CGRect] {
        guard let mainDisplay = NSScreen.screens.first,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
                as? [[String: Any]] else { return [] }
        return PillCoverArea.menuBars(in: windows, mainDisplayHeight: mainDisplay.frame.height)
    }

    /// The window a press at `point` would reach, passing over the app's own windows other than the status
    /// item's, `pillWindow`: the Panel's anchor over the Pill while the Panel is open, and the cover, which
    /// the window server can still find for a moment after it is taken away. Seen on macOS 27: below the
    /// cover the menu bar is found rather than the shown Pill, so `PillCoverArea.placement` doesn't look
    /// while the cover is up.
    private static func windowBelowOwnWindows(at point: CGPoint, pillWindow: Int) -> Int {
        var found = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)
        var passed: Set<Int> = []
        while !PillCoverArea.isPillWindow(found, pillWindow: pillWindow),
              NSApp.window(withWindowNumber: found) != nil, passed.insert(found).inserted {
            found = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: found)
        }
        return found
    }

    /// Places the cover when the Pill may have come under the pointer without the pointer moving: the app
    /// becomes active, the displays change, or the Space changes, as when leaving another app's full screen.
    private func observeApp() {
        let place = placeOnNotification
        let center = NotificationCenter.default
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didChangeScreenParametersNotification] {
            center.addObserver(forName: name, object: nil, queue: .main, using: place)
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main, using: place)
    }

    /// Places the cover when the status item appears, moves, resizes or changes screen. Watches the status
    /// item's window as it is now, moving its observers over if the status item was given another window.
    private func observeStatusItemWindow() {
        let window = statusItem.button?.window
        guard window !== observedWindow else { return }
        let center = NotificationCenter.default
        for observer in windowObservers { center.removeObserver(observer) }
        windowObservers = []
        observedWindow = window
        guard let window else { return }
        windowObservers = [NSWindow.didMoveNotification, NSWindow.didResizeNotification,
                           NSWindow.didChangeScreenNotification].map { name in
            center.addObserver(forName: name, object: window, queue: .main, using: placeOnNotification)
        }
    }

    private var placeOnNotification: @Sendable (Notification) -> Void {
        { [weak self] _ in MainActor.assumeIsolated { self?.place() } }
    }
}

extension NSStatusItem {
    /// The status item's frame on screen, and the screen it is on.
    @MainActor
    var frameOnScreen: (frame: CGRect, screen: NSScreen)? {
        guard let button, let window = button.window, let screen = window.screen else { return nil }
        return (window.convertToScreen(button.convert(button.bounds, to: nil)), screen)
    }
}
