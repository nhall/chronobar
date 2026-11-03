import AppKit
import SwiftUI
import ChronobarCore
import KeyboardShortcuts
import os

/// The Pill's AppKit shell: an `NSStatusItem` hosting `PillView`, split into two click zones.
/// The square toggles the timer; the time segment opens the Panel.
@MainActor
final class StatusItemController: NSObject {
    private let tracker: Tracker
    private let panel = PanelModel()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let pill: NSHostingView<PillView>

    init(tracker: Tracker, preferences: Preferences, loginItem: LoginItem) {
        self.tracker = tracker
        pill = ClickThroughHostingView(rootView: PillView(tracker: tracker, preferences: preferences))
        super.init()

        popover.behavior = .transient
        let content = NSHostingController(rootView: PanelView(
            tracker: tracker, panel: panel, preferences: preferences, loginItem: loginItem,
            start: { [weak self] project in self?.perform { try tracker.start(project) } },
            pause: { [weak self] in self?.perform { try tracker.pause() } },
            archive: { [weak self] project in self?.perform { try tracker.archiveProject(project) } },
            close: { [weak self] in self?.popover.performClose(nil) },
            quit: { NSApp.terminate(nil) }))
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
        // The global shortcut does exactly what a click on the square does.
        KeyboardShortcuts.onKeyUp(for: .toggleTimer) { [weak self] in self?.toggle() }
        refresh()
    }

    /// Resizes the status item to fit the Pill, whose time segment widens past `9:59`.
    func refresh() {
        let width = ceil(pill.fittingSize.width)
        if statusItem.length != width { statusItem.length = width }
    }

    @objc private func clicked(_ button: NSStatusBarButton) {
        let x = NSApp.currentEvent.map { button.convert($0.locationInWindow, from: nil).x } ?? .infinity
        let squareEnd = PillMetrics.inset + PillMetrics.squareWidth + PillMetrics.gap / 2
        if x < squareEnd {
            toggle()
        } else {
            showPanel(newProject: false)
        }
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
        // Picks up hand edits to the Day file and the Project list.
        tracker.reload()
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            Logger(subsystem: "Chronobar", category: "tracker").error("\(error, privacy: .public)")
            NSSound.beep()
        }
        refresh()
    }
}

/// Lets clicks fall through to the status bar button, which owns click handling and highlighting.
private final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
