import AppKit
import SwiftUI
import ChronobarCore

/// The ＋ form's Label field: a native `NSComboBox`, so VoiceOver, Full Keyboard Access and larger text
/// come with it. ▾ or ↓ opens the list of `suggestions(typed)`, where `typed` is what was last typed rather
/// than a name filled in from the list, so moving through the list doesn't narrow it. Typing narrows the
/// list and opens it while anything matches, and closes it when nothing does. There is no inline
/// completion, so what was typed is never replaced by a longer name. Return on an item highlighted in the
/// open list picks it, fills the field and closes the list; otherwise Return submits. Right-clicking a name
/// in the open list offers Pin (unless pinned) and Archive.
struct ProjectComboBox: NSViewRepresentable {
    @Binding var name: String
    /// Whether the list is showing. The form's default button gives up Return meanwhile, so Return can
    /// pick from the list.
    @Binding var isListOpen: Bool
    let suggestions: (String) -> [String]
    /// Bumped to put focus in the field.
    let focusRequests: Int
    let submit: () -> Void
    let isPinned: (String) -> Bool
    let pin: (String) -> Void
    let archive: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSComboBox {
        let box = NSComboBox()
        box.usesDataSource = true
        box.dataSource = context.coordinator
        box.delegate = context.coordinator
        box.completes = false
        box.numberOfVisibleItems = 10
        box.hasVerticalScroller = true
        box.placeholderString = "Label"
        box.setAccessibilityLabel("Label")
        box.lineBreakMode = .byTruncatingTail
        box.cell?.isScrollable = true
        box.setContentHuggingPriority(.defaultLow, for: .horizontal)
        box.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        context.coordinator.box = box
        // The form's own focus on appearing: the window may not be there until the next turn.
        DispatchQueue.main.async { box.window?.makeFirstResponder(box) }
        return box
    }

    func updateNSView(_ box: NSComboBox, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if box.stringValue != name {
            box.stringValue = name
            // Text set from outside (cleared after Start, Log or Archive) is the new filter.
            coordinator.typed = name
        }
        coordinator.refresh(open: nil)
        if coordinator.focusRequests != focusRequests {
            coordinator.focusRequests = focusRequests
            DispatchQueue.main.async { box.window?.makeFirstResponder(box) }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSComboBoxDataSource, NSComboBoxDelegate, NSMenuDelegate {
        var parent: ProjectComboBox?
        weak var box: NSComboBox?
        var typed = ""
        var focusRequests = 0
        private var items: [String] = []
        /// Whether the list is showing, from the combo box's will-pop-up and will-dismiss notifications.
        private var isOpen = false

        /// Reloads the list for `typed` if it changed, and opens or closes it when `open` says so.
        func refresh(open: Bool?) {
            guard let parent, let box else { return }
            let next = parent.suggestions(typed)
            if next != items {
                items = next
                box.reloadData()
                box.noteNumberOfItemsChanged()
            }
            if let open { setOpen(open && !items.isEmpty) }
        }

        /// `NSComboBox` has no public call to show or hide its list. Setting its cell's accessibility
        /// expanded state is what VoiceOver does to open it, and it pops the real list up or down, with the
        /// will-pop-up and will-dismiss notifications that keep `isOpen` and `isListOpen` in step.
        private func setOpen(_ open: Bool) {
            guard let box, open != isOpen else { return }
            box.cell?.setAccessibilityExpanded(open)
        }

        func numberOfItems(in comboBox: NSComboBox) -> Int { items.count }

        func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
            items.indices.contains(index) ? items[index] : nil
        }

        func comboBox(_ comboBox: NSComboBox, indexOfItemWithStringValue string: String) -> Int {
            items.firstIndex(of: string) ?? NSNotFound
        }

        func comboBoxWillPopUp(_ notification: Notification) {
            isOpen = true
            parent?.isListOpen = true
            // The list's window is put up after this notification.
            DispatchQueue.main.async { [weak self] in self?.attachMenu() }
        }

        /// The right-click menu on the open list's names, rebuilt for the clicked one each time.
        private lazy var listMenu: NSMenu = {
            let menu = NSMenu()
            menu.delegate = self
            return menu
        }()
        private weak var listTable: NSTableView?

        /// `NSComboBox` has no public way to reach its list. The list is a table in a window of its own,
        /// so it is found among the app's visible windows by its class name, and given `listMenu`.
        private func attachMenu() {
            guard listTable == nil || listTable?.window?.isVisible != true else { return }
            for window in NSApp.windows
            where window.isVisible && String(describing: type(of: window)).contains("ComboBox") {
                if let table = window.contentView.flatMap(Self.table(in:)) {
                    table.menu = listMenu
                    listTable = table
                    return
                }
            }
        }

        private static func table(in view: NSView) -> NSTableView? {
            if let table = view as? NSTableView { return table }
            for subview in view.subviews { if let table = table(in: subview) { return table } }
            return nil
        }

        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            guard let parent, let row = listTable?.clickedRow, items.indices.contains(row) else { return }
            let project = items[row]
            if !parent.isPinned(project) {
                menu.addItem(item("Pin “\(project)”", project, #selector(pinClicked(_:))))
            }
            menu.addItem(item("Archive “\(project)”", project, #selector(archiveClicked(_:))))
        }

        private func item(_ title: String, _ project: String, _ action: Selector) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = project
            return item
        }

        @objc private func pinClicked(_ item: NSMenuItem) {
            guard let project = item.representedObject as? String else { return }
            parent?.pin(project)
        }

        @objc private func archiveClicked(_ item: NSMenuItem) {
            guard let project = item.representedObject as? String else { return }
            parent?.archive(project)
        }

        func comboBoxWillDismiss(_ notification: Notification) {
            isOpen = false
            parent?.isListOpen = false
        }

        /// A name was clicked or moved to in the list: the field holds it, the filter stays as typed.
        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let box, items.indices.contains(box.indexOfSelectedItem) else { return }
            let picked = items[box.indexOfSelectedItem]
            box.stringValue = picked
            parent?.name = picked
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let box else { return }
            typed = box.stringValue
            parent?.name = typed
            // The highlight from moving through the list goes, so Return then acts on what was typed.
            if box.indexOfSelectedItem >= 0 { box.deselectItem(at: box.indexOfSelectedItem) }
            refresh(open: !ProjectName.trimmed(typed).isEmpty)
        }

        /// Every other key, ↓ and ↑ included, is the combo box's own: ↓ opens the list, then moves through it.
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard let box, selector == #selector(NSResponder.insertNewline(_:)) else { return false }
            // The combo box's own Return picks the highlighted item, fills the field and closes the list.
            if isOpen && box.indexOfSelectedItem >= 0 { return false }
            setOpen(false)
            parent?.name = box.stringValue
            parent?.submit()
            return true
        }
    }
}
