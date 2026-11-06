import CoreGraphics

/// Where the Pill's cover goes. The cover is an invisible window that takes a press on the Pill before the
/// menu bar can, so the menu bar draws no highlight behind it. It is only there while the pointer is on the
/// status item, so it never stands in front of anything else.
public enum PillCoverArea {
    /// The cover's frame for a status item at `item` on a screen whose frame is `screen` and whose area
    /// left by the menu bar and Dock is `visible`, all in screen coordinates with y up. It spans the item's
    /// width, from its bottom to the top of the screen, so a press at the very top is covered too. Nil, so
    /// the press goes to the menu bar as usual, when the pointer is elsewhere, while ⌘ is held (⌘-drag moves
    /// the item), or when the menu bar is hidden.
    public static func frame(item: CGRect, screen: CGRect, visible: CGRect, pointer: CGPoint,
                             commandKey: Bool) -> CGRect? {
        guard !commandKey, visible.maxY <= item.minY else { return nil }
        let area = CGRect(x: item.minX, y: item.minY, width: item.width, height: screen.maxY - item.minY)
        let over = (area.minX..<area.maxX).contains(pointer.x) && (area.minY...area.maxY).contains(pointer.y)
        return over ? area : nil
    }
}
