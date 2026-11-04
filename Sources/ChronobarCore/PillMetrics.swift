import Foundation

/// The Pill's horizontal layout in points, which both its drawing and its click zones follow. The sizes
/// only the drawing needs live with `PillView`.
public enum PillMetrics {
    /// Space between the Pill and the edges of the status item.
    public static let inset: CGFloat = 3
    public static let squareWidth: CGFloat = 22
    public static let gap: CGFloat = 2
    /// Where the square's click zone ends and the time segment's begins: halfway across the gap.
    public static let squareZoneEnd: CGFloat = inset + squareWidth + gap / 2
}
