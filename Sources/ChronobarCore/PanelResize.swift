import Foundation

/// The Panel's height while it grows or shrinks to fit its content, as when the ＋ form opens or closes.
/// The popover would otherwise jump to the new height in one step. With Reduce Motion it still does.
public struct PanelResize: Equatable, Sendable {
    /// How long the change takes.
    public static let duration: TimeInterval = 0.2

    public let from: Double
    public let to: Double
    private let length: TimeInterval

    public init(from: Double, to: Double, reduceMotion: Bool) {
        self.from = from
        self.to = to
        length = reduceMotion ? 0 : Self.duration
    }

    /// The height `elapsed` seconds after the change began.
    public func height(after elapsed: TimeInterval) -> Double {
        if isFinished(after: elapsed) { return to }
        let progress = max(elapsed / length, 0)
        // Ease out (cubic): quick at first, settling into place.
        let eased = 1 - pow(1 - progress, 3)
        return from + (to - from) * eased
    }

    public func isFinished(after elapsed: TimeInterval) -> Bool {
        elapsed >= length
    }
}
