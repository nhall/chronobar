import AppKit
import SwiftUI
import ChronobarCore

/// The ＋ form's Label field: a text field with ▾, and a list of suggestions Chronobar draws itself in a
/// window under the field, so its right-click menu is set through public API. `SuggestionList` decides what
/// the list shows and what each key and click does; this draws it. ▾ or ↓ opens the list of
/// `suggestions(filter)`, where `filter` is what was last typed rather than a name ↓ moved to, so moving
/// through the list doesn't narrow it. Typing narrows the list and opens it while anything matches, and
/// closes it when nothing does. There is no inline completion, so what was typed is never replaced by a
/// longer name. Return on a highlighted name picks it, fills the field and closes the list; otherwise
/// Return submits. Escape closes the list, or with it closed calls `cancel`, if given. Right-clicking a name offers Pin (unless pinned) and Archive.
struct LabelField: NSViewRepresentable {
    @Binding var name: String
    /// Whether the list is showing. The form's default button gives up Return meanwhile, so Return can
    /// pick from the list.
    @Binding var isListOpen: Bool
    let suggestions: (String) -> [String]
    /// Bumped to put focus in the field.
    let focusRequests: Int
    let submit: () -> Void
    /// Escape with the list closed, as a row's Label field uses it; nil leaves Escape to the window.
    var cancel: (() -> Void)? = nil
    let isPinned: (String) -> Bool
    let pin: (String) -> Void
    let archive: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> LabelFieldView {
        let coordinator = context.coordinator
        coordinator.parent = self
        let view = LabelFieldView(coordinator: coordinator)
        coordinator.view = view
        coordinator.set(name)
        // The form's own focus on appearing: the window may not be there until the next turn.
        DispatchQueue.main.async { view.window?.makeFirstResponder(view.field) }
        return view
    }

    func updateNSView(_ view: LabelFieldView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if view.field.stringValue != name {
            view.field.stringValue = name
            // Text set from outside (cleared after Start, Log or Archive) is the new filter.
            coordinator.set(name)
        } else {
            coordinator.reload()
        }
        if coordinator.focusRequests != focusRequests {
            coordinator.focusRequests = focusRequests
            // Not while editing: focusing the field again would end the editing, and close the list.
            DispatchQueue.main.async {
                if view.field.currentEditor() == nil { view.window?.makeFirstResponder(view.field) }
            }
        }
    }

    static func dismantleNSView(_ view: LabelFieldView, coordinator: Coordinator) {
        coordinator.hideList()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
        var parent: LabelField?
        weak var view: LabelFieldView?
        var focusRequests = 0
        private var list = SuggestionList()
        /// The rows the table shows, `list.items` when it last reloaded.
        private var shown: [String] = []
        private lazy var window = SuggestionWindow(coordinator: self)
        private var resignObserver: NSObjectProtocol?

        var isOpen: Bool { list.isOpen }

        func set(_ text: String) {
            guard let parent else { return }
            list.set(text, suggestions: parent.suggestions(text))
            apply()
        }

        /// Picks up suggestions changed under the list, such as a name just pinned or archived from it.
        func reload() {
            guard let parent else { return }
            list.reload(parent.suggestions(list.filter))
            apply()
        }

        func hideList() {
            list.close()
            apply()
        }

        @objc func toggle(_ sender: Any?) {
            guard let view else { return }
            if view.field.currentEditor() == nil { view.window?.makeFirstResponder(view.field) }
            reload()
            list.toggle()
            apply()
        }

        /// Draws `list`: the rows, the highlight, the window and the field's expanded state.
        private func apply() {
            guard let view else { return }
            if shown != list.items {
                shown = list.items
                window.table.reloadData()
            }
            if let row = list.highlighted {
                window.table.selectRowIndexes([row], byExtendingSelection: false)
                window.table.scrollRowToVisible(row)
            } else {
                window.table.deselectAll(nil)
            }
            if list.isOpen, let parentWindow = view.window {
                window.show(under: view, in: parentWindow)
                observeResignKey(of: parentWindow)
            } else if window.isVisible {
                window.hide()
            }
            if parent?.isListOpen != list.isOpen {
                // Not while SwiftUI is updating the view.
                let open = list.isOpen
                DispatchQueue.main.async { [weak self] in
                    if self?.list.isOpen == open { self?.parent?.isListOpen = open }
                }
            }
        }

        /// The list closes with the Panel, whose window stops being key.
        private func observeResignKey(of parentWindow: NSWindow) {
            guard resignObserver == nil else { return }
            resignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification, object: parentWindow, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.hideList()
                    if let observer = self.resignObserver { NotificationCenter.default.removeObserver(observer) }
                    self.resignObserver = nil
                }
            }
        }

        /// Puts `text` in the field and in the form, as typing would, without changing the filter.
        private func fill(_ text: String) {
            view?.field.stringValue = text
            parent?.name = text
        }

        // MARK: Field

        func controlTextDidChange(_ notification: Notification) {
            guard let view, let parent else { return }
            let text = view.field.stringValue
            parent.name = text
            list.typed(text, suggestions: parent.suggestions(text))
            apply()
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            hideList()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            let key: SuggestionList.Key
            switch selector {
            case #selector(NSResponder.moveDown(_:)): key = .down
            case #selector(NSResponder.moveUp(_:)): key = .up
            case #selector(NSResponder.insertNewline(_:)): key = .return
            case #selector(NSResponder.cancelOperation(_:)): key = .escape
            default: return false
            }
            if key == .down { list.reload(parent?.suggestions(list.filter) ?? []) }
            let outcome = list.press(key)
            switch outcome {
            case .ignored:
                guard key == .escape, let cancel = parent?.cancel else { return false }
                cancel()
            case .handled:
                apply()
            case .show(let text):
                fill(text)
                apply()
                announceHighlight()
            case .pick(let text):
                fill(text)
                apply()
            case .submit:
                apply()
                parent?.name = view?.field.stringValue ?? ""
                parent?.submit()
            }
            return true
        }

        /// VoiceOver stays in the field as ↓ and ↑ move, so it is told the name moved to.
        private func announceHighlight() {
            guard NSWorkspace.shared.isVoiceOverEnabled, let text = list.spokenHighlight, let view else { return }
            NSAccessibility.post(
                element: view.field, notification: .announcementRequested,
                userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
        }

        // MARK: List

        func numberOfRows(in tableView: NSTableView) -> Int { shown.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let id = NSUserInterfaceItemIdentifier("suggestion")
            let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView ?? {
                let cell = NSTableCellView()
                cell.identifier = id
                let text = NSTextField(labelWithString: "")
                text.lineBreakMode = .byTruncatingTail
                text.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(text)
                cell.textField = text
                NSLayoutConstraint.activate([
                    text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                ])
                return cell
            }()
            cell.textField?.stringValue = shown.indices.contains(row) ? shown[row] : ""
            return cell
        }

        /// Only `list` highlights rows: a click picks a name (`clicked`) rather than selecting it.
        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { false }

        @objc func clicked(_ table: NSTableView) {
            guard let text = list.click(row: table.clickedRow) else { return }
            fill(text)
            apply()
        }

        /// The right-click menu for the name on `row`.
        func menu(forRow row: Int) -> NSMenu? {
            guard let parent, let label = list.label(atRow: row) else { return nil }
            let menu = NSMenu()
            for entry in SuggestionList.menu(for: label, isPinned: parent.isPinned(label)) {
                let action = switch entry.action {
                case .pin: #selector(pinClicked(_:))
                case .archive: #selector(archiveClicked(_:))
                }
                let item = NSMenuItem(title: entry.title, action: action, keyEquivalent: "")
                item.target = self
                item.representedObject = entry.label
                menu.addItem(item)
            }
            return menu
        }

        @objc private func pinClicked(_ item: NSMenuItem) {
            guard let label = item.representedObject as? String else { return }
            parent?.pin(label)
        }

        @objc private func archiveClicked(_ item: NSMenuItem) {
            guard let label = item.representedObject as? String else { return }
            parent?.archive(label)
        }
    }
}

/// The field and its ▾, side by side.
final class LabelFieldView: NSView {
    let field = LabelTextField()
    private let disclosure: NSButton

    init(coordinator: LabelField.Coordinator) {
        disclosure = NSButton(
            image: NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Suggestions") ?? NSImage(),
            target: coordinator, action: #selector(LabelField.Coordinator.toggle(_:)))
        super.init(frame: .zero)
        field.delegate = coordinator
        field.isExpanded = { [weak coordinator] in coordinator?.isOpen ?? false }
        field.placeholderString = "Label"
        field.setAccessibilityLabel("Label")
        field.bezelStyle = .roundedBezel
        field.lineBreakMode = .byTruncatingTail
        field.cell?.isScrollable = true
        field.usesSingleLineMode = true
        disclosure.isBordered = false
        disclosure.imageScaling = .scaleProportionallyDown
        disclosure.refusesFirstResponder = true
        disclosure.contentTintColor = .secondaryLabelColor
        disclosure.setAccessibilityLabel("Suggestions")
        disclosure.toolTip = "Suggestions"
        for view in [field, disclosure] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: leadingAnchor),
            field.topAnchor.constraint(equalTo: topAnchor),
            field.bottomAnchor.constraint(equalTo: bottomAnchor),
            disclosure.leadingAnchor.constraint(equalTo: field.trailingAnchor, constant: 2),
            disclosure.trailingAnchor.constraint(equalTo: trailingAnchor),
            disclosure.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            disclosure.widthAnchor.constraint(equalToConstant: 16),
        ])
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: field.intrinsicContentSize.height)
    }
}

/// The field VoiceOver reads as a combo box, with whether its list is open.
final class LabelTextField: NSTextField {
    var isExpanded: () -> Bool = { false }

    override func accessibilityRole() -> NSAccessibility.Role? { .comboBox }
    override func isAccessibilityExpanded() -> Bool { isExpanded() }
}

/// The window the suggestions show in: under the field, attached to the Panel's window so it moves with
/// it, and never key, so typing stays in the field.
private final class SuggestionWindow: NSPanel {
    let table = SuggestionTable()
    private let scroll = NSScrollView()
    /// The most rows shown before the list scrolls.
    private static let visibleRows = 10
    private static let inset = 4.0

    init(coordinator: LabelField.Coordinator) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
                   defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = true
        becomesKeyOnlyIfNeeded = true

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("label"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.style = .plain
        table.rowHeight = 20
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.backgroundColor = .clear
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.dataSource = coordinator
        table.delegate = coordinator
        table.target = coordinator
        table.action = #selector(LabelField.Coordinator.clicked(_:))
        table.refusesFirstResponder = true
        table.menuForRow = { [weak coordinator] row in coordinator?.menu(forRow: row) }
        table.setAccessibilityLabel("Suggestions")

        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        let background = NSVisualEffectView()
        background.material = .menu
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 6
        background.layer?.masksToBounds = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: background.topAnchor, constant: Self.inset),
            scroll.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -Self.inset),
        ])
        contentView = background
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Shows the list under `view`, or over it when the screen has no room below, as wide as `view`.
    func show(under view: NSView, in parentWindow: NSWindow) {
        let rows = min(table.numberOfRows, Self.visibleRows)
        let height = CGFloat(rows) * table.rowHeight + 2 * Self.inset
        let anchor = parentWindow.convertToScreen(view.convert(view.bounds, to: nil))
        var frame = NSRect(x: anchor.minX, y: anchor.minY - 2 - height, width: anchor.width, height: height)
        if let visible = parentWindow.screen?.visibleFrame, frame.minY < visible.minY {
            frame.origin.y = anchor.maxY + 2
        }
        if self.frame != frame { setFrame(frame, display: true) }
        if parent !== parentWindow {
            parent?.removeChildWindow(self)
            parentWindow.addChildWindow(self, ordered: .above)
        }
        if !isVisible { orderFront(nil) }
    }

    func hide() {
        parent?.removeChildWindow(self)
        orderOut(nil)
    }
}

/// The suggestions' table: clicks reach it though its window is never key, and a right-click asks for
/// the menu of the row under the pointer.
private final class SuggestionTable: NSTableView {
    var menuForRow: (Int) -> NSMenu? = { _ in nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func menu(for event: NSEvent) -> NSMenu? {
        menuForRow(row(at: convert(event.locationInWindow, from: nil)))
    }
}
