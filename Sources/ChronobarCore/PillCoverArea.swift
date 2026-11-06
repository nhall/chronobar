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
        /// The cover goes away for now: the pointer is where the status item is, but the Pill isn't shown
        /// there (yet). An auto-hidden menu bar slides in a moment after the pointer reaches the top of the
        /// screen, so look again shortly.
        case awaitingPill
    }

    /// Where the cover goes for a status item at `item` on a screen whose frame is `screen`, all in screen
    /// coordinates with y up. It spans the item's width, from its bottom to the top of the screen, so a
    /// press at the very top is covered too.
    ///
    /// It is away when the pointer is elsewhere, while ⌘ is held (⌘-drag moves the item), and while
    /// `pressHeld`: a press is under way that the cover didn't take, and it stays with whatever took it.
    ///
    /// The status item keeps its frame while the Pill isn't shown there, so two more things must say it
    /// is. `menuBars` are the frames of the menu bars on screen now: an auto-hidden menu bar may be away.
    /// `windowAtPill` is the window the window server finds at the Pill, under the cover, and `pillWindow`
    /// the status item's own window (`isPillWindow`): a Pill pushed into the « overflow has the chevron or
    /// another status item where it was, and in another app's full screen the window list reports the menu
    /// bar even while it is away. Both are only worked out with the pointer on the status item.
    ///
    /// Under the cover the window server finds the menu bar rather than the Pill, so with the cover up
    /// (`coverUp`) the window at the Pill isn't looked at: the cover went up only where the Pill was found.
    public static func placement(item: CGRect, screen: CGRect, pointer: CGPoint, commandKey: Bool,
                                 pressHeld: Bool, menuBars: @autoclosure () -> [CGRect],
                                 windowAtPill: @autoclosure () -> Int, pillWindow: Int,
                                 coverUp: Bool) -> Placement {
        guard !commandKey, !pressHeld else { return .away }
        let area = CGRect(x: item.minX, y: item.minY, width: item.width, height: screen.maxY - item.minY)
        guard isOn(area, pointer) else { return .away }
        let centre = CGPoint(x: item.midX, y: item.midY)
        guard menuBars().contains(where: { $0.contains(centre) }),
              coverUp || isPillWindow(windowAtPill(), pillWindow: pillWindow) else { return .awaitingPill }
        return .cover(area)
    }

    /// Whether `found`, a window number from `NSWindow.windowNumber(at:belowWindowWithWindowNumber:)`, is
    /// the status item's window, whose `NSWindow.windowNumber` is `pillWindow`. The window server's numbers
    /// are 32 bits; AppKit gives a status item's window a number above that whose low 32 bits are the ones
    /// the window server finds (seen on macOS 27, where they are 0).
    public static func isPillWindow(_ found: Int, pillWindow: Int) -> Bool {
        found == pillWindow || found == pillWindow & 0xFFFF_FFFF
    }

    /// Whether `point` is on `area`, with y up. Unlike `CGRect.contains`, the top edge counts: the pointer
    /// stops there at the very top of the screen, and a press there is on the Pill.
    public static func isOn(_ area: CGRect, _ point: CGPoint) -> Bool {
        (area.minX..<area.maxX).contains(point.x) && (area.minY...area.maxY).contains(point.y)
    }

    /// The owner name the window list gives the window server's own windows, the menu bars among them.
    static let windowServerOwnerName = "Window Server"

    /// The frames of the menu bars on screen, from `windows` as `CGWindowListCopyWindowInfo` lists them, in
    /// screen coordinates with y up. The window list puts y down from the top of the main display, which is
    /// `mainDisplayHeight` tall. A menu bar is the window server's window at the main menu level; an
    /// auto-hidden one stays listed while away, off screen.
    public static func menuBars(in windows: [[String: Any]], mainDisplayHeight: CGFloat) -> [CGRect] {
        let level = Int(CGWindowLevelForKey(.mainMenuWindow))
        return windows.compactMap { window in
            guard window[kCGWindowOwnerName as String] as? String == windowServerOwnerName,
                  window[kCGWindowLayer as String] as? Int == level,
                  window[kCGWindowIsOnscreen as String] as? Bool == true,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return nil }
            return CGRect(x: frame.minX, y: mainDisplayHeight - frame.maxY, width: frame.width, height: frame.height)
        }
    }
}
