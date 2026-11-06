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
    private let cover = PillCover()
    private let pill: NSHostingView<PillView>
    private var press = PillPress()
    private var focusObserver: NSObjectProtocol?
    /// Hosts the Panel in the popover, at its content's height.
    private var sizer: PanelSizer?
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
        sizer = PanelSizer(popover: popover, content: PanelView(
            tracker: tracker, panel: panel, preferences: preferences, loginItem: loginItem,
            appName: variant.appName, actions: actions))

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
        // reaches the button. One with ⌘ held is the start of a ⌘-drag, and does nothing.
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            let window = event.window
            let commandKey = event.modifierFlags.contains(.command)
            let taken = MainActor.assumeIsolated {
                guard let self, let button = self.statusItem.button else { return false }
                // With another app frontmost the app never sees ⌘ go down, so the cover can still be over
                // the Pill; it goes now, so the next press reaches the menu bar for its ⌘-drag.
                self.placeCover(pressCommandKey: commandKey)
                guard let action = self.press.mouseDown(
                    onPill: self.isOnPill(window), at: Self.pointer(over: button), commandKey: commandKey,
                    panelOpen: self.popover.isShown, tracker: self.tracker) else { return false }
                self.run(action, by: .pointer)
                return true
            }
            return taken ? nil : event
        }
        // The cover goes over the Pill while the pointer is on it, so a press reaches the app without the
        // menu bar drawing its highlight. Its mouse-up stands in for the button's action.
        cover.onMouseUp = { [weak self] overPill in
            guard let self, let action = self.press.mouseUp(overPill: overPill, tracker: self.tracker) else { return }
            self.run(action, by: .pointer)
        }
        // Pointer moves and ⌘ over other apps, then over this one.
        let followPointer: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.placeCover() }
        }
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .flagsChanged], handler: followPointer)
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .flagsChanged]) { event in
            followPointer(event)
            return event
        }
        // The Panel's key equivalents, ahead of the focused control so they work wherever focus is, with
        // Keyboard navigation on or off. A key that would edit text in a focused field passes through.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let window = event.window
            let key = PanelKey.Key(event)
            let modifiers = PanelKey.Modifiers(event.modifierFlags)
            let taken = MainActor.assumeIsolated {
                self?.handlePanelKey(key, modifiers: modifiers, in: window) ?? false
            }
            return taken ? nil : event
        }
        // The global shortcut does exactly what a click on the square does, and tells VoiceOver what that was.
        KeyboardShortcuts.onKeyUp(for: .toggleTimer) { [weak self] in
            guard let self else { return }
            let action = PillClick.square(tracker: tracker)
            let before = tracker.running
            run(action, by: .keyboard)
            announce(ShortcutAnnouncement.text(for: action, before: before, after: tracker))
        }
        refresh()
    }

    /// Resizes the status item to fit the Pill, whose time segment widens past `9:59`, and keeps an open
    /// Panel's anchor over it.
    func refresh() {
        let width = ceil(pill.fittingSize.width)
        if statusItem.length != width { statusItem.length = width }
        if popover.isShown, let button = statusItem.button {
            anchor.place(over: button)
            capPanel()
        }
        describe()
    }

    /// Caps the Panel's height at the room under the Pill on the Pill's screen (`PanelHeight`).
    private func capPanel() {
        guard let pill = pillFrame(), let screen = statusItem.button?.window?.screen else { return }
        let available = PanelHeight.available(under: pill, visible: screen.visibleFrame, chrome: panelChrome)
        if panel.availableHeight != available { panel.availableHeight = available }
    }

    /// The status item's frame on screen.
    private func pillFrame() -> CGRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    /// The points the popover's window takes under the Pill besides the Panel: its arrow above the Panel and
    /// its frame and shadow below, which must stay on screen too or the popover moves off the Pill. Measured
    /// each time the Panel shows (`popoverDidShow`); until then, what the popover took when this was written.
    private var panelChrome = 27.0

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
                run(PillClick.square(tracker: tracker), by: .keyboard)
                return true
            },
            NSAccessibilityCustomAction(name: PillAccessibility.openPanelAction) { [weak self] in
                self?.showPanel(by: .keyboard)
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
        if let action = press.buttonAction(byMouse: byMouse ?? false, tracker: tracker) {
            run(action, by: byMouse == true ? .pointer : .keyboard)
        }
    }

    /// The transient Panel would close on the mouse-down of a click on the square, before that mouse-down
    /// reaches the event monitor. A click on the time segment or anywhere else still closes it.
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        guard let event = NSApp.currentEvent, event.type == .leftMouseDown,
              let button = statusItem.button else { return true }
        return PillPress.closesPanel(
            onPill: isOnPill(event.window), at: Self.pointer(over: button), tracker: tracker)
    }

    /// Whether a mouse-down in `window` is on the Pill: in the status item's own window, or in the cover
    /// over it, which has the same frame.
    private func isOnPill(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        return window === statusItem.button?.window || window === cover
    }

    /// Puts the cover over the Pill while the pointer is on it, and takes it away otherwise
    /// (`PillCoverArea`). Run on every pointer move, so it follows the status item wherever it goes, and on
    /// every mouse-down. At a mouse-down, `pressCommandKey` is whether that press had ⌘ held, and the cover
    /// can go even from under it.
    private func placeCover(pressCommandKey: Bool? = nil) {
        let duringPress = pressCommandKey != nil
        guard let item = pillFrame(), let screen = statusItem.button?.window?.screen else {
            return cover.remove(duringPress: duringPress)
        }
        let frame = PillCoverArea.frame(
            item: item, screen: screen.frame, visible: screen.visibleFrame, pointer: NSEvent.mouseLocation,
            commandKey: pressCommandKey ?? NSEvent.modifierFlags.contains(.command))
        if let frame { cover.place(at: frame) } else { cover.remove(duringPress: duringPress) }
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
    /// whether it ran. Any key pressed there, command or not, shows the focus ring.
    private func handlePanelKey(_ key: PanelKey.Key?, modifiers: PanelKey.Modifiers, in window: NSWindow?) -> Bool {
        guard popover.isShown, let window,
              let panelWindow = popover.contentViewController?.view.window,
              window === panelWindow || window.parent === panelWindow else { return false }
        panel.keyPressed()
        guard let key else { return false }
        // A focused text field edits through its field editor, a text view.
        let editingText = (window.firstResponder as? NSTextView)?.isEditable ?? false
        guard let command = PanelKey.command(for: key, modifiers: modifiers, editingText: editingText)
        else { return false }
        panel.perform(command, today: tracker.today, calendar: tracker.calendar)
        return true
    }

    /// Runs a Pill action from a click, or from the keyboard or VoiceOver.
    private func run(_ action: PillClick, by opening: PanelOpening) {
        switch action {
        case .toggleTimer: perform { try tracker.toggle() }
        case .openPanel: showPanel(newProject: false, by: opening)
        case .openNewProjectForm: showPanel(newProject: true, by: opening)
        }
    }

    /// Has VoiceOver speak `text`, with VoiceOver running. The shortcut works from any app and moves
    /// VoiceOver's attention nowhere, so nothing else tells a VoiceOver user what it did.
    private func announce(_ text: String?) {
        guard let text, NSWorkspace.shared.isVoiceOverEnabled else { return }
        NSAccessibility.post(
            element: NSApp as Any, notification: .announcementRequested,
            userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    /// Opens the Panel, with focus on today's date or in the ＋ form's Project field. After a click on the
    /// Pill the focus ring stays hidden until a key press in the Panel (`FocusRing`).
    func showPanel(newProject: Bool = false, by opening: PanelOpening) {
        panel.showingNewProject = newProject
        if popover.isShown {
            panel.askedToOpenWhileOpen(by: opening)
            return
        }
        panel.opened(by: opening)
        guard let button = statusItem.button else { return }
        // Each opening starts on today, picks up hand edits to any Day file and the Project list, and
        // retries writes deferred while a Day file was malformed. Tick first so a timer running past
        // midnight rolls over before today's file is re-read.
        tracker.tick()
        tracker.reload()
        panel.viewedDay = nil
        panel.showingSummary = false
        refresh()
        // Not the cooperative `activate()`: when a press reaches the status item through the menu bar, as it
        // does when the cover isn't over the Pill, the system refuses that request. The Panel still becomes
        // key, but the app only really activates on the next click in it, and that activation closes the ⚙
        // menu the click just opened.
        NSApp.activate(ignoringOtherApps: true)
        anchor.place(over: button)
        capPanel()
        sizer?.fitBeforeShowing()
        popover.show(relativeTo: anchor.view.bounds, of: anchor.view, preferredEdge: .minY)
        if let window = popover.contentViewController?.view.window { settleFocus(in: window, newProject: newProject) }
    }

    /// Measures `panelChrome` from the popover as shown, in case the system draws it differently, and caps
    /// the Panel again if it changed.
    func popoverDidShow(_ notification: Notification) {
        guard let window = popover.contentViewController?.view.window, let pill = pillFrame() else { return }
        let chrome = (pill.minY - window.frame.minY - popover.contentSize.height).rounded(.up)
        guard chrome > 0, chrome != panelChrome else { return }
        panelChrome = chrome
        capPanel()
    }

    func popoverDidClose(_ notification: Notification) {
        anchor.orderOut(nil)
    }

    /// The Panel's window can only take focus once it is key, which from an inactive app can be after `show`
    /// returns. So once the window is key, focus moves to the ＋ form's Project field, or with the form
    /// closed to the date header, today's date, wherever it was when the Panel last closed.
    private func settleFocus(in window: NSWindow, newProject: Bool) {
        if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }
        focusObserver = nil
        if window.isKeyWindow { return settle(newProject: newProject) }
        focusObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.settle(newProject: newProject)
                if let observer = self.focusObserver { NotificationCenter.default.removeObserver(observer) }
                self.focusObserver = nil
            }
        }
    }

    private func settle(newProject: Bool) {
        if newProject { panel.newProjectFocusRequests += 1 } else { panel.headerFocusRequests += 1 }
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
