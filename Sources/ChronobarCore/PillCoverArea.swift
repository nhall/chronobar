import CoreGraphics
import Foundation

/// Where the Pill's cover goes. The cover is an invisible window that takes a press on the Pill before the
/// menu bar can, so the menu bar draws no highlight behind it. It is only there while the pointer is on the
/// status item and the menu bar is shown there, so it never stands in front of anything else.
public enum PillCoverArea {
    public enum Placement: Equatable, Sendable {
        /// The cover goes up with this frame.
        case cover(CGRect)
        /// The cover goes away, so a press reaches whatever is under the pointer.
        case away
        /// The cover goes away for now: the pointer is where the status item is, but the menu bar isn't
        /// shown there (yet). An auto-hidden menu bar slides in a moment after the pointer reaches the top
        /// of the screen, so look again shortly.
        case awaitingMenuBar
    }

    /// Where the cover goes for a status item at `item` on a screen whose frame is `screen`, all in screen
    /// coordinates with y up. It spans the item's width, from its bottom to the top of the screen, so a
    /// press at the very top is covered too.
    ///
    /// It is away when the pointer is elsewhere, while ⌘ is held (⌘-drag moves the item), and while
    /// `pressHeld`: a press is under way that the cover didn't take, and it stays with whatever took it.
    /// `menuBars` are the frames of the menu bars on screen now; the status item keeps its frame while an
    /// auto-hidden menu bar is away, so only a menu bar under it says the status item is really there. They
    /// are only worked out with the pointer on the status item.
    public static func placement(item: CGRect, screen: CGRect, pointer: CGPoint, commandKey: Bool,
                                 pressHeld: Bool, menuBars: @autoclosure () -> [CGRect]) -> Placement {
        guard !commandKey, !pressHeld else { return .away }
        let area = CGRect(x: item.minX, y: item.minY, width: item.width, height: screen.maxY - item.minY)
        guard isOn(area, pointer) else { return .away }
        let centre = CGPoint(x: item.midX, y: item.midY)
        return menuBars().contains { $0.contains(centre) } ? .cover(area) : .awaitingMenuBar
    }

    /// Whether `point` is on `area`, with y up. Unlike `CGRect.contains`, the top edge counts: the pointer
    /// stops there at the very top of the screen, and a press there is on the Pill.
    public static func isOn(_ area: CGRect, _ point: CGPoint) -> Bool {
        (area.minX..<area.maxX).contains(point.x) && (area.minY...area.maxY).contains(point.y)
    }

    /// The frames of the menu bars on screen, from `windows` as `CGWindowListCopyWindowInfo` lists them, in
    /// screen coordinates with y up. The window list puts y down from the top of the main display, which is
    /// `mainDisplayHeight` tall. A menu bar is the window server's window at the main menu level; an
    /// auto-hidden one stays listed while away, off screen.
    public static func menuBars(in windows: [[String: Any]], mainDisplayHeight: CGFloat) -> [CGRect] {
        let level = Int(CGWindowLevelForKey(.mainMenuWindow))
        return windows.compactMap { window in
            guard window[kCGWindowOwnerName as String] as? String == "Window Server",
                  window[kCGWindowLayer as String] as? Int == level,
                  window[kCGWindowIsOnscreen as String] as? Bool == true,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return nil }
            return CGRect(x: frame.minX, y: mainDisplayHeight - frame.maxY, width: frame.width, height: frame.height)
        }
    }
}
