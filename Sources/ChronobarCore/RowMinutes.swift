import Foundation

/// The whole minutes shown for rows under their total, so that the rows add up to it: 2:08:45 and 1:08:49
/// show as 2:08 and 1:09 under Total 3:17. The total is rounded down to the minute; rounding each row down
/// too loses some minutes, and those go one each to the rows with the most seconds left over, the first
/// row winning a tie. A row below zero counts as zero, as it shows 0:00, and every row counts in whole
/// seconds, as the command line receives them, so the Panel and the command line show the same minutes.
public struct RowMinutes: Equatable, Sendable {
    /// Each row's minutes, in the order given.
    public let rows: [Int]
    public let total: Int

    public init(seconds: [TimeInterval]) {
        let seconds = seconds.map { Int(max(0, $0)) }
        total = seconds.reduce(0, +) / 60
        var rows = seconds.map { $0 / 60 }
        let lost = total - rows.reduce(0, +)
        let leftOver = seconds.map { $0 % 60 }
        let mostLeftOver = seconds.indices.sorted { (-leftOver[$0], $0) < (-leftOver[$1], $1) }
        for index in mostLeftOver.prefix(lost) { rows[index] += 1 }
        self.rows = rows
    }
}
