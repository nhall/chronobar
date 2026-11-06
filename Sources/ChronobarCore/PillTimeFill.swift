import Foundation

/// The dark fill behind the Pill's white time. By default the menu bar shows through a little; Reduce
/// Transparency makes it opaque, and Increase Contrast makes it opaque, darker, and outlined so it stands
/// off a dark menu bar.
public struct PillTimeFill: Equatable, Sendable {
    public let color: SRGB
    public let opacity: Double
    /// Whether to draw a light edge around it.
    public let outlined: Bool

    public init(increaseContrast: Bool, reduceTransparency: Bool) {
        let gray = increaseContrast ? 0.08 : 0.18
        color = SRGB(red: gray, green: gray, blue: gray)
        opacity = increaseContrast || reduceTransparency ? 1 : 0.85
        outlined = increaseContrast
    }
}
