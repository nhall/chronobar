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
        self.init(seconds: seconds, total: seconds.map { Int(max(0, $0)) }.reduce(0, +) / 60)
    }

    /// Rows that add up to a `total` set elsewhere, such as a week's: the sum of its Day lines, each
    /// rounded down on its own, which can be a few minutes less than the rows' time rounded down. Rows
    /// rounded down then come to too many minutes, and those come off one each, again and again if need
    /// be, from the rows with the fewest seconds left over, the first row on a tie; no row goes below zero.
    /// Too few minutes go to the rows with the most seconds left over, as without a `total`.
    public init(seconds: [TimeInterval], total: Int) {
        let seconds = seconds.map { Int(max(0, $0)) }
        self.total = total
        var rows = seconds.map { $0 / 60 }
        let leftOver = seconds.map { $0 % 60 }
        var missing = total - rows.reduce(0, +)
        if missing > 0, !rows.isEmpty {
            let mostLeftOver = rows.indices.sorted { (-leftOver[$0], $0) < (-leftOver[$1], $1) }
            for index in (0..<missing).map({ mostLeftOver[$0 % rows.count] }) { rows[index] += 1 }
        }
        let fewestLeftOver = rows.indices.sorted { (leftOver[$0], $0) < (leftOver[$1], $1) }
        while missing < 0, rows.contains(where: { $0 > 0 }) {
            for index in fewestLeftOver where missing < 0 && rows[index] > 0 {
                rows[index] -= 1
                missing += 1
            }
        }
        self.rows = rows
    }
}
