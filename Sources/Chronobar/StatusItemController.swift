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
    private let anchor = PanelAnchor()
    private let pill: NSHostingView<PillView>
    private var press = PillPress()
    private var focusObserver: NSObjectProtocol?
    /// What VoiceOver was last given for the Pill.
    private var described: PillAccessibility?

    init(tracker: Tracker, variant: BuildVariant, storageRoot: URL, preferences: Preferences,
         loginItem: LoginItem) {
        self.tracker = tracker
        pill = ClickThroughHostingView(
            rootView: PillView(tracker: tracker, preferences: preferences, badge: variant.badge))
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
            tracker: tracker, panel: panel, preferences: preferences, loginItem: loginItem,
            appName: variant.appName, actions: actions))
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
        // Every left mouse-down in the app passes through here, before the status item's button or the
        // Panel's own handling. With the Panel open, one on the square runs at once and is dropped before it
        // reaches the button.
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            let window = event.window
            let taken = MainActor.assumeIsolated {
                guard let self, let button = self.statusItem.button else { return false }
                guard let action = self.press.mouseDown(
                    onStatusItem: window === button.window, at: Self.pointer(over: button),
                    panelOpen: self.popover.isShown, tracker: self.tracker) else { return false }
                self.run(action)
                return true
            }
            return taken ? nil : event
        }
        // The Panel's key equivalents, ahead of the focused control so they work wherever focus is, with
        // Keyboard navigation on or off. A key that would edit text in a focused field passes through.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let window = event.window
            let key = Self.panelKey(keyCode: event.keyCode, characters: event.charactersIgnoringModifiers)
            let modifiers = Self.panelModifiers(event.modifierFlags)
            let taken = MainActor.assumeIsolated {
                self?.handlePanelKey(key, modifiers: modifiers, in: window) ?? false
            }
            return taken ? nil : event
        }
        // The global shortcut does exactly what a click on the square does.
        KeyboardShortcuts.onKeyUp(for: .toggleTimer) { [weak self] in
            self?.run(PillClick.square(tracker: tracker))
        }
        refresh()
    }

    /// Resizes the status item to fit the Pill, whose time segment widens past `9:59`, and keeps an open
    /// Panel's anchor over it.
    func refresh() {
        let width = ceil(pill.fittingSize.width)
        if statusItem.length != width { statusItem.length = width }
        if popover.isShown, let button = statusItem.button { anchor.place(over: button) }
        describe()
    }

    /// VoiceOver lands on the status item's button, so the button carries what the Pill shows and the
    /// actions a click on each segment takes. Its own press opens the Panel. The actions are only replaced
    /// when their names change, so VoiceOver's actions menu isn't rebuilt every second.
    private func describe() {
        guard let button = statusItem.button else { return }
        let description = PillAccessibility(tracker: tracker)
        if button.accessibilityLabel() != description.label { button.setAccessibilityLabel(description.label) }
        guard description.squareAction != described?.squareAction else { return }
        described = description
        button.setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: description.squareAction) { [weak self] in
                guard let self else { return false }
                run(PillClick.square(tracker: tracker))
                return true
            },
            NSAccessibilityCustomAction(name: PillAccessibility.openPanelAction) { [weak self] in
                self?.showPanel()
                return self != nil
            },
        ])
    }

    /// The status item's button action: a click on the Pill with the Panel closed, or a press from VoiceOver
    /// or the keyboard. The menu bar hands the app its mouse events at the status item's
    /// centre wherever the click was, so the zone comes from the pointer's position at the mouse-down.
    @objc private func clicked(_ button: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let byMouse = event.map { [.leftMouseDown, .leftMouseUp].contains($0.type) && $0.window === button.window }
        run(press.buttonAction(byMouse: byMouse ?? false, tracker: tracker))
    }

    /// The transient Panel would close on the mouse-down of a click on the square, before that mouse-down
    /// reaches the event monitor. A click on the time segment or anywhere else still closes it.
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        guard let event = NSApp.currentEvent, event.type == .leftMouseDown,
              let button = statusItem.button else { return true }
        return PillPress.closesPanel(
            onStatusItem: event.window === button.window, at: Self.pointer(over: button), tracker: tracker)
    }

    /// The pointer's x from the button's leading edge, over the status item when it is within the status
    /// item's window, padding included. Read from the pointer's screen position rather than an event's,
    /// which the menu bar places at the status item's centre.
    private static func pointer(over button: NSStatusBarButton) -> PillPointer {
        guard let window = button.window else { return .away }
        let x = button.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil).x
        let leading = button.convert(NSPoint.zero, from: nil).x
        return PillPointer(x: x, within: leading...(leading + window.frame.width))
    }

    /// Runs the Panel command for a key pressed in the Panel or the (i) Time Summary it shows, and returns
    /// whether it ran.
    private func handlePanelKey(_ key: PanelKey.Key?, modifiers: PanelKey.Modifiers, in window: NSWindow?) -> Bool {
        guard popover.isShown, let key, let window,
              let panelWindow = popover.contentViewController?.view.window,
              window === panelWindow || window.parent === panelWindow else { return false }
        // A focused text field edits through its field editor, a text view.
        let editingText = (window.firstResponder as? NSTextView)?.isEditable ?? false
        guard let command = PanelKey.command(for: key, modifiers: modifiers, editingText: editingText)
        else { return false }
        panel.perform(command, today: tracker.today, calendar: tracker.calendar)
        return true
    }

    private static func panelKey(keyCode: UInt16, characters: String?) -> PanelKey.Key? {
        switch keyCode {
        case 123: .leftArrow
        case 124: .rightArrow
        default: characters.map { .character($0) }
        }
    }

    private static func panelModifiers(_ flags: NSEvent.ModifierFlags) -> PanelKey.Modifiers {
        var modifiers: PanelKey.Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        return modifiers
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
        anchor.place(over: button)
        popover.show(relativeTo: anchor.view.bounds, of: anchor.view, preferredEdge: .minY)
        if let window = popover.contentViewController?.view.window { settleFocus(in: window, newProject: newProject) }
    }

    func popoverDidClose(_ notification: Notification) {
        anchor.orderOut(nil)
    }

    /// AppKit focuses the first control, the date header, and draws its ring, when the Panel's window
    /// becomes key, which from an inactive app can be after `show` returns. So once the window is key, focus
    /// moves to the ＋ form's Project field, or with the form closed to nothing. With nothing focused, Tab
    /// still moves focus to the header and on through the Panel, with its ring.
    private func settleFocus(in window: NSWindow, newProject: Bool) {
        if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }
        focusObserver = nil
        if window.isKeyWindow { return settle(window, newProject: newProject) }
        focusObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let window = self.popover.contentViewController?.view.window else { return }
                self.settle(window, newProject: newProject)
                if let observer = self.focusObserver { NotificationCenter.default.removeObserver(observer) }
                self.focusObserver = nil
            }
        }
    }

    private func settle(_ window: NSWindow, newProject: Bool) {
        if newProject { panel.newProjectFocusRequests += 1 } else { window.makeFirstResponder(nil) }
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

/// An invisible window over the status item that the Panel hangs from. The menu bar draws its highlight
/// behind a status item for as long as a popover is shown from a view in the item's own window, so the
/// Panel is shown from this window instead, which puts it in the same place.
private final class PanelAnchor: NSPanel {
    /// The view the Panel is shown from, filling the window.
    let view = NSView()

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
                   defer: true)
        contentView = view
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // Clicks go through to the Pill underneath.
        ignoresMouseEvents = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Covers `button` on screen, and shows. Called every second while the Panel is open, so it does
    /// nothing unless the status item moved or resized, or the anchor was hidden.
    func place(over button: NSStatusBarButton) {
        guard let window = button.window else { return }
        let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
        guard frame != self.frame || !isVisible else { return }
        setFrame(frame, display: false)
        orderFrontRegardless()
    }
}
