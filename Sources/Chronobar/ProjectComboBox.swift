import AppKit
import SwiftUI
import ChronobarCore

/// The ＋ form's Project field: a native `NSComboBox`, so VoiceOver, Full Keyboard Access and larger text
/// come with it. ▾ or ↓ opens the list of `suggestions(typed)`, where `typed` is what was last typed rather
/// than a name filled in from the list, so moving through the list doesn't narrow it. Typing narrows the
/// list and opens it while anything matches. There is no inline completion, so what was typed is never
/// replaced by a longer name. Return on an item highlighted in the open list picks it and closes the list;
/// otherwise Return submits.
struct ProjectComboBox: NSViewRepresentable {
    @Binding var name: String
    /// Whether the list is showing. The form's default button gives up Return meanwhile, so Return can
    /// pick from the list.
    @Binding var isListOpen: Bool
    let suggestions: (String) -> [String]
    /// Bumped to put focus in the field.
    let focusRequests: Int
    let submit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSComboBox {
        let box = NSComboBox()
        box.usesDataSource = true
        box.dataSource = context.coordinator
        box.delegate = context.coordinator
        box.completes = false
        box.numberOfVisibleItems = 10
        box.hasVerticalScroller = true
        box.placeholderString = "Project"
        box.setAccessibilityLabel("Project")
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
    final class Coordinator: NSObject, NSComboBoxDataSource, NSComboBoxDelegate {
        var parent: ProjectComboBox?
        weak var box: NSComboBox?
        var typed = ""
        var focusRequests = 0
        private var items: [String] = []
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
            if box.indexOfSelectedItem >= 0 { box.deselectItem(at: box.indexOfSelectedItem) }
            refresh(open: !ProjectName.trimmed(typed).isEmpty)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard let box else { return false }
            switch selector {
            case #selector(NSResponder.moveDown(_:)) where !isOpen:
                refresh(open: true)
                return true
            case #selector(NSResponder.insertNewline(_:)):
                if isOpen && box.indexOfSelectedItem >= 0 {
                    setOpen(false)
                    return true
                }
                setOpen(false)
                parent?.name = box.stringValue
                parent?.submit()
                return true
            default:
                return false
            }
        }
    }
}
