import AppKit
import SwiftUI
import ChronobarCore
import KeyboardShortcuts

/// The Pill's AppKit shell: an `NSStatusItem` hosting `PillView`. Any click on it opens the Panel.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let tracker: Tracker
    private let panel = PanelModel()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let anchor = PanelAnchor()
    private let pill: NSHostingView<PillView>
    private var focusObserver: NSObjectProtocol?
    /// Hosts the Panel in the popover, at its content's height.
    private var sizer: PanelSizer?

    init(tracker: Tracker, variant: BuildVariant, storageRoot: URL, preferences: Preferences,
         loginItem: LoginItem) {
        self.tracker = tracker
        pill = ClickThroughHostingView(
            rootView: PillView(tracker: tracker, preferences: preferences, badge: variant.badge))
        super.init()

        popover.behavior = .transient
        popover.delegate = self
        let actions = PanelActions(
            start: { [weak self] project in self?.attempt { try tracker.start(project) } },
            toggle: { [weak self] project in self?.perform { try tracker.toggle(project) } },
            log: { [weak self] project, duration, day in
                self?.attempt { try tracker.log(project, duration, on: day).project }
            },
            adjust: { [weak self] project, input, day in
                self?.perform { try tracker.adjust(project, input, on: day) } ?? false
            },
            archive: { [weak self] project in self?.perform { try tracker.archiveProject(project) } },
            pin: { [weak self] project in self?.perform { try tracker.pinProject(project) } },
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
        // The Panel's key equivalents, ahead of the focused control so they work wherever focus is, with
        // Keyboard navigation on or off. A key that would edit text in a focused field passes through.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let window = event.window
            let keyCode = event.keyCode
            let modifiers = PanelKey.Modifiers(event.modifierFlags)
            let taken = MainActor.assumeIsolated {
                self?.handlePanelKey(keyCode, modifiers: modifiers, in: window) ?? false
            }
            return taken ? nil : event
        }
        // The global shortcut opens the Panel, as a click on the Pill does, and tells VoiceOver so.
        KeyboardShortcuts.onKeyUp(for: .openPanel) { [weak self] in
            guard let self else { return }
            showPanel(by: .keyboard)
            announce(ShortcutAnnouncement.text(tracker: tracker))
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
        guard let (pill, screen) = statusItem.frameOnScreen else { return }
        let available = PanelHeight.available(under: pill, visible: screen.visibleFrame, chrome: panelChrome)
        if panel.availableHeight != available { panel.availableHeight = available }
    }

    /// The points the popover's window takes under the Pill besides the Panel: its arrow above the Panel and
    /// its frame and shadow below, which must stay on screen too or the popover moves off the Pill. Measured
    /// each time the Panel is about to show (`measureChrome`), before its first frame; until the first
    /// measure, what the popover took when this was written.
    private var panelChrome = 27.0

    /// VoiceOver lands on the status item's button, so the button carries what the Pill shows. Its own
    /// press opens the Panel, as a click does; there is nothing else to offer as an action.
    private func describe() {
        guard let button = statusItem.button else { return }
        let label = PillAccessibility(tracker: tracker).label
        if button.accessibilityLabel() != label { button.setAccessibilityLabel(label) }
    }

    /// The status item's button action: a click on the Pill, or a press from VoiceOver or the keyboard. It
    /// opens the Panel. With the Panel open, the click's mouse-down closes it, and its action arrives while
    /// the Panel is still closing, so `showPanel` leaves it closed. A ⌘-drag, which the menu bar handles,
    /// sends no action (ADR 0007).
    @objc private func clicked(_ button: NSStatusBarButton) {
        let byMouse = NSApp.currentEvent.map {
            [.leftMouseDown, .leftMouseUp].contains($0.type) && $0.window === button.window
        } ?? false
        showPanel(by: byMouse ? .pointer : .keyboard)
    }

    /// Runs the Panel command for a key pressed in the Panel or the (i) Time Summary it shows, and returns
    /// whether it ran. Any key pressed there, command or not, shows the focus ring.
    private func handlePanelKey(_ keyCode: UInt16, modifiers: PanelKey.Modifiers, in window: NSWindow?) -> Bool {
        guard popover.isShown, let window,
              let panelWindow = popover.contentViewController?.view.window,
              window === panelWindow || window.parent === panelWindow else { return false }
        panel.keyPressed()
        // A focused text field edits through its field editor, a text view.
        let editingText = (window.firstResponder as? NSTextView)?.isEditable ?? false
        guard let command = PanelKey.command(
            keyCode: keyCode, modifiers: modifiers, layout: PanelKey.currentLayout(), editingText: editingText)
        else { return false }
        panel.perform(command, today: tracker.today, calendar: tracker.calendar)
        return true
    }

    /// Has VoiceOver speak `text`, with VoiceOver running. The shortcut works from any app and moves
    /// VoiceOver's attention nowhere, so nothing else tells a VoiceOver user what it did.
    private func announce(_ text: String?) {
        guard let text, NSWorkspace.shared.isVoiceOverEnabled else { return }
        NSAccessibility.post(
            element: NSApp as Any, notification: .announcementRequested,
            userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    /// Opens the Panel, with focus on today's date or in the ＋ form's Label field. After a click on the
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
        // retries writes deferred while a Day file was malformed. `reload()` rolls a timer running past
        // midnight over first.
        tracker.reload()
        panel.viewedDay = nil
        panel.showingSummary = false
        refresh()
        // Not a plain `activate()`, which macOS turns down when the press reached the status item through the
        // menu bar or came from VoiceOver: the first click in the Panel would then activate the app for real
        // and close the ⚙ menu it opened (#23).
        NSApp.comeToFront()
        anchor.place(over: button)
        capPanel()
        sizer?.fitBeforeShowing()
        popover.show(relativeTo: anchor.view.bounds, of: anchor.view, preferredEdge: .minY)
        if let window = popover.contentViewController?.view.window { settleFocus(in: window, newProject: newProject) }
    }

    /// The popover's window is laid out by now but not yet on screen, so a Panel capped with the wrong
    /// chrome is refitted before its first frame rather than animating once open.
    func popoverWillShow(_ notification: Notification) {
        measureChrome()
    }

    /// In case the window wasn't laid out round the Panel when it was about to show.
    func popoverDidShow(_ notification: Notification) {
        measureChrome()
    }

    /// Measures `panelChrome` from the popover's window (`PanelHeight.chrome`), and caps and fits the Panel
    /// again if it changed.
    private func measureChrome() {
        guard let view = popover.contentViewController?.view, let window = view.window,
              let pill = statusItem.frameOnScreen?.frame,
              let chrome = PanelHeight.chrome(window: window.frame.height,
                                              panel: view.convert(view.bounds, to: nil).height,
                                              pillBottom: pill.minY),
              chrome != panelChrome else { return }
        panelChrome = chrome
        capPanel()
        sizer?.fitBeforeShowing()
    }

    func popoverDidClose(_ notification: Notification) {
        anchor.orderOut(nil)
    }

    /// The Panel's window can only take focus once it is key, which from an inactive app can be after `show`
    /// returns. So once the window is key, focus moves to the ＋ form's Label field, or with the form
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
        attempt(action) != nil
    }

    /// Runs a Core command and returns what it returned; on an error logs it, beeps and returns nil.
    private func attempt<Result>(_ action: () throws -> Result) -> Result? {
        defer { refresh() }
        do {
            return try action()
        } catch {
            reportFailure(error, category: "tracker")
            return nil
        }
    }
}

private extension NSStatusItem {
    /// The status item's frame on screen, and the screen it is on.
    @MainActor
    var frameOnScreen: (frame: CGRect, screen: NSScreen)? {
        guard let button, let frame = button.frameOnScreen, let screen = button.window?.screen else { return nil }
        return (frame, screen)
    }
}

private extension NSStatusBarButton {
    /// The button's frame on screen, or nil while it isn't in a window.
    var frameOnScreen: CGRect? {
        guard let window else { return nil }
        return window.convertToScreen(convert(bounds, to: nil))
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
        guard let frame = button.frameOnScreen, frame != self.frame || !isVisible else { return }
        setFrame(frame, display: false)
        orderFrontRegardless()
    }
}
