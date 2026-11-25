#if canImport(CoreGraphics)
import CoreGraphics
#else
import Foundation  // CGRect, for the Linux build of `chronobar mcp` (ADR 0009)
#endif

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

    /// The most `chrome` can plausibly be: a popover's arrow, frame and shadow take a few tens of points.
    public static let maximumChrome = 64.0

    /// The `chrome` for `available`, measured from the popover's window: `window` points tall with the Panel
    /// `panel` points tall in it, hung from a Pill whose bottom is at `pillBottom`. The window's top sits at
    /// the Pill's bottom snapped down to a whole point. Only heights are used, not where the window is, so
    /// a popover the system squeezed onto the screen or moved off the Pill still measures right. Nil for a
    /// measure that can't be a popover's frame, as before its window is laid out round the Panel.
    public static func chrome(window: Double, panel: Double, pillBottom: Double) -> Double? {
        let frame = window - panel
        guard frame > 0, frame <= maximumChrome else { return nil }
        return (frame + pillBottom - pillBottom.rounded(.down)).rounded(.up)
    }

    /// The rows' height for rows `natural` points tall when nothing caps them, with `rest` points of the
    /// Panel's content around them (the header, the Week strip, ＋ and an open ＋ form) and `available`
    /// points for all of it. Less than `natural`, the rows scroll within it.
    public static func rows(natural: Double, rest: Double, available: Double) -> Double {
        min(natural, max(available - rest, minimumRows))
    }
}
