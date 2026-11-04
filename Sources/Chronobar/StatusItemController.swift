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
    private let square = SquareClickView()

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
        // The square takes its own clicks, so they never reach the button and its Panel action.
        square.translatesAutoresizingMaskIntoConstraints = false
        square.onClick = { [weak self] in self?.toggle() }
        button.addSubview(square)
        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            pill.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            square.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            square.widthAnchor.constraint(
                equalToConstant: PillMetrics.inset + PillMetrics.squareWidth + PillMetrics.gap / 2),
            square.topAnchor.constraint(equalTo: button.topAnchor),
            square.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])
        button.target = self
        button.action = #selector(clicked(_:))
        // The global shortcut does exactly what a click on the square does.
        KeyboardShortcuts.onKeyUp(for: .toggleTimer) { [weak self] in self?.toggle() }
        refresh()
    }

    /// Resizes the status item to fit the Pill, whose time segment widens past `9:59`.
    func refresh() {
        let width = ceil(pill.fittingSize.width)
        if statusItem.length != width { statusItem.length = width }
    }

    /// A click on the time segment; the square's clicks never get here.
    @objc private func clicked(_ button: NSStatusBarButton) {
        showPanel(newProject: false)
    }

    /// The open Panel is transient and would close on the mouse-down of a click on the square.
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        !(square.containsMouse && NSEvent.pressedMouseButtons & 1 != 0)
    }

    private func toggle() {
        if tracker.running == nil && tracker.selectedProject == nil {
            showPanel(newProject: true)
        } else {
            perform { try tracker.toggle() }
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

/// The Pill's square as a click target. It handles the click itself rather than passing it on to the
/// status bar button, whose action opens the Panel.
private final class SquareClickView: NSView {
    var onClick: () -> Void = {}

    /// Read from the pointer's screen position rather than an event's, which may belong to another window.
    var containsMouse: Bool {
        guard let window else { return false }
        let point = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        return bounds.contains(point)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    // Overridden so the mouse-down isn't passed up the responder chain to the button.
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
        if containsMouse { onClick() }
    }
}

/// Lets clicks fall through to the status bar button, which owns click handling and highlighting.
private final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
