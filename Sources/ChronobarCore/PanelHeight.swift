import CoreGraphics

/// How tall the Panel can be: no taller than the room under the Pill on its screen. Past that only the rows
/// scroll, so the header, the Week strip, and ＋ with its form stay in view.
public enum PanelHeight {
    /// The gap kept between the Panel and the bottom of the screen's visible area.
    public static let margin = 8.0
    /// The least the rows get when they scroll, about two rows, on a screen too short for the rest of the
    /// Panel: the Panel then passes the screen's edge rather than hide every row.
    public static let minimumRows = 56.0

    /// The most the Panel's content can be for a Pill at `pill` on a screen whose area left by the menu bar
    /// and Dock is `visible`, both in screen coordinates with y up: from the Pill's bottom, where the Panel
    /// hangs from, down to the visible area's bottom, less `chrome` (the popover's frame and arrow around its
    /// content) and `margin`.
    public static func available(under pill: CGRect, visible: CGRect, chrome: Double) -> Double {
        max(Double(pill.minY - visible.minY) - chrome - margin, 0)
    }

    /// The rows' height for rows `natural` points tall when nothing caps them, with `rest` points of the
    /// Panel's content around them (the header, the Week strip, ＋ and an open ＋ form) and `available`
    /// points for all of it.
    public static func rows(natural: Double, rest: Double, available: Double) -> PanelRows {
        let room = max(available - rest, minimumRows)
        return natural > room ? PanelRows(height: room, scrolls: true) : PanelRows(height: natural, scrolls: false)
    }
}

/// How tall the Panel's rows are, and whether they scroll within that.
public struct PanelRows: Equatable, Sendable {
    public let height: Double
    public let scrolls: Bool

    public init(height: Double, scrolls: Bool) {
        self.height = height
        self.scrolls = scrolls
    }
}
