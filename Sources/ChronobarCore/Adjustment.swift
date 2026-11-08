import Foundation

/// What an adjustment did: the Project it adjusted, as stored, on which Day, and the Project's Total on
/// that Day before and after, floored to whole seconds as Chronobar shows them. Equal Totals mean it wrote
/// nothing.
public struct Adjustment: Equatable, Sendable {
    /// The spelling of the Project's row on that Day, else its stored spelling.
    public let project: String
    public let day: Day
    /// Whole seconds.
    public let before: Int
    /// Whole seconds.
    public let after: Int

    public init(project: String, day: Day, before: Int, after: Int) {
        self.project = project
        self.day = day
        self.before = before
        self.after = after
    }

    /// The change to the Total as shown: after minus before, in whole seconds.
    public var change: Int { after - before }
}
