import AppKit
import SwiftUI
import ChronobarCore
import KeyboardShortcuts

/// The Pill's AppKit shell: an `NSStatusItem` hosting `PillView`, split into two click zones.
/// The square toggles the timer; the time segment opens the Panel.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let tracker: Tracker
    private let panel = PanelModel()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let pill: NSHostingView<PillView>

    init(tracker: Tracker, storageRoot: URL, preferences: Preferences, loginItem: LoginItem) {
        self.tracker = tracker
        pill = ClickThroughHostingView(rootView: PillView(tracker: tracker, preferences: preferences))
        super.init()

        popover.behavior = .transient
        popover.delegate = self
        let actions = PanelActions(
            start: { [weak self] project in self?.perform { try tracker.start(project) } },
            toggle: { [weak self] project in self?.perform { try tracker.toggle(project) } },
            log: { [weak self] project, duration, day in
                self?.perform { try tracker.log(project, duration, on: day) } ?? false
            },
            adjust: { [weak self] project, input, day in
                self?.perform { try tracker.adjust(project, input, on: day) } ?? false
            },
            archive: { [weak self] project in self?.perform { try tracker.archiveProject(project) } },
            openDataFolder: { [weak self] in
                self?.popover.performClose(nil)
                // The folder only exists after the first write.
                try? FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)
                NSWorkspace.shared.open(storageRoot)
            },
            quit: { NSApp.terminate(nil) })
        let content = NSHostingController(rootView: PanelView(
            tracker: tracker, panel: panel, preferences: preferences, loginItem: loginItem, actions: actions))
        content.sizingOptions = .preferredContentSize
        popover.contentViewController = content

        guard let button = statusItem.button else { return }
        pill.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(pill)
        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            pill.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])
        button.target = self
        button.action = #selector(clicked(_:))
        // While the Panel is open the button sends no action for a click on the Pill, so the square's
        // mouse-downs are run here instead, and dropped before they reach the button.
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            let window = event.window
            let taken = MainActor.assumeIsolated {
                guard let self, let action = self.squareClickWithPanelOpen(in: window) else { return false }
                self.run(action)
                return true
            }
            return taken ? nil : event
        }
        // The global shortcut does exactly what a click on the square does.
        KeyboardShortcuts.onKeyUp(for: .toggleTimer) { [weak self] in
            self?.run(PillClick.square(tracker: tracker))
        }
        refresh()
    }

    /// Resizes the status item to fit the Pill, whose time segment widens past `9:59`.
    func refresh() {
        let width = ceil(pill.fittingSize.width)
        if statusItem.length != width { statusItem.length = width }
    }

    /// Every click on the Pill lands here, square or time segment. The menu bar hands the app a mouse-down
    /// at the status item's centre wherever the click was, so neither the event's position nor a subview
    /// over the square can tell the zones apart. The pointer's own position can.
    @objc private func clicked(_ button: NSStatusBarButton) {
        run(PillClick.action(atX: pointerX(in: button), tracker: tracker))
    }

    /// The transient Panel would close on the mouse-down of a click on the square, before that mouse-down
    /// reaches the event monitor. A click on the time segment still closes it.
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        guard let event = NSApp.currentEvent, event.type == .leftMouseDown else { return true }
        return squareClickWithPanelOpen(in: event.window) == nil
    }

    /// For a mouse-down in the status item's window while the Panel is open: the square's action, or nil
    /// when the click is on the time segment or elsewhere.
    private func squareClickWithPanelOpen(in window: NSWindow?) -> PillClick? {
        guard popover.isShown, let button = statusItem.button, window === button.window else { return nil }
        let action = PillClick.action(atX: pointerX(in: button), tracker: tracker)
        return action == .openPanel ? nil : action
    }

    /// The pointer's x from the button's leading edge, or nil when it is off the button (a press from
    /// VoiceOver or the keyboard).
    private func pointerX(in button: NSStatusBarButton) -> Double? {
        guard let window = button.window else { return nil }
        let point = button.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        return button.bounds.contains(point) ? point.x : nil
    }

    private func run(_ action: PillClick) {
        switch action {
        case .toggleTimer: perform { try tracker.toggle() }
        case .openPanel: showPanel(newProject: false)
        case .openNewProjectForm: showPanel(newProject: true)
        }
    }

    func showPanel(newProject: Bool = false) {
        panel.showingNewProject = newProject
        if popover.isShown { return }
        guard let button = statusItem.button else { return }
        // Each opening starts on today, picks up hand edits to any Day file and the Project list, and
        // retries writes deferred while a Day file was malformed. Tick first so a timer running past
        // midnight rolls over before today's file is re-read.
        tracker.tick()
        tracker.reload()
        panel.viewedDay = nil
        panel.showingSummary = false
        refresh()
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // AppKit would focus the first control, the date header, and draw its ring on every opening. With
        // nothing focused, Tab still moves focus to the header and on through the Panel, with its ring. The ＋
        // form, opened from the Pill, focuses its Project field itself.
        if !newProject { popover.contentViewController?.view.window?.makeFirstResponder(nil) }
    }

    /// Runs a Core command; on an error (a typo in a duration, a malformed Day file) logs it, beeps and
    /// returns false.
    @discardableResult
    private func perform(_ action: () throws -> Void) -> Bool {
        defer { refresh() }
        do {
            try action()
            return true
        } catch {
            reportFailure(error, category: "tracker")
            return false
        }
    }
}

/// Lets clicks fall through to the status bar button, which owns click handling and highlighting.
private final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
