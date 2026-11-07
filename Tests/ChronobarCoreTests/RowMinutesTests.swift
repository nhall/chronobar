import Foundation
import Testing
import ChronobarCore

private func hms(_ hours: Int, _ minutes: Int, _ seconds: Int) -> TimeInterval {
    TimeInterval(hours * 3600 + minutes * 60 + seconds)
}

/// Rows shown under a total add up to it: the total is rounded down to the minute, and the minutes the
/// rows lose to rounding down go to the rows with the most seconds left over.
@Suite struct RowMinutesTests {
    @Test func theMinuteLostToRoundingGoesToTheRowWithTheMostSecondsLeftOver() {
        let minutes = RowMinutes(seconds: [hms(2, 8, 45), hms(1, 8, 49)])

        #expect(minutes.total == 3 * 60 + 17)
        #expect(minutes.rows == [2 * 60 + 8, 60 + 9])
    }

    @Test func theLargestLeftoverWinsWhereverItsRowIs() {
        #expect(RowMinutes(seconds: [70, 110]).rows == [1, 2])
        #expect(RowMinutes(seconds: [110, 70]).rows == [2, 1])
    }

    @Test func aTieGoesToTheFirstRow() {
        let minutes = RowMinutes(seconds: [30, 30])

        #expect(minutes.total == 1)
        #expect(minutes.rows == [1, 0])
    }

    @Test func wholeMinuteRowsAreShownAsTheyAre() {
        let minutes = RowMinutes(seconds: [3600, 20 * 60, 0])

        #expect(minutes.total == 80)
        #expect(minutes.rows == [60, 20, 0])
    }

    @Test func noRowsAddUpToZero() {
        let minutes = RowMinutes(seconds: [])

        #expect(minutes.total == 0)
        #expect(minutes.rows == [])
    }

    /// A row adjusted below zero shows 0:00 and counts as zero toward the total.
    @Test func aNegativeRowCountsAsZero() {
        let minutes = RowMinutes(seconds: [-600, 90, 90])

        #expect(minutes.total == 3)
        #expect(minutes.rows == [0, 2, 1])
    }

    /// Rows count in whole seconds, as the command line and JSON give them, so both show the same minutes.
    @Test func fractionsOfASecondAreDroppedFromEachRowFirst() {
        let minutes = RowMinutes(seconds: [59.9, 0.9])

        #expect(minutes.total == 0)
        #expect(minutes.rows == [0, 0])
    }

    @Test func manyRowsShareTheLostMinutesInOrder() {
        let minutes = RowMinutes(seconds: Array(repeating: 59, count: 10))

        #expect(minutes.total == 9)
        #expect(minutes.rows == Array(repeating: 1, count: 9) + [0])
    }

    @Test func rowsAlwaysAddUpAndStayWithinAMinuteOfTheirOwnTime() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<500 {
            let seconds = (0..<Int.random(in: 0...12, using: &generator)).map { _ in
                TimeInterval(Int.random(in: -3600...36_000, using: &generator))
            }
            let minutes = RowMinutes(seconds: seconds)

            #expect(minutes.rows.reduce(0, +) == minutes.total)
            #expect(minutes.total == Int(seconds.map { max(0, $0) }.reduce(0, +)) / 60)
            for (row, value) in zip(minutes.rows, seconds) {
                let own = Int(max(0, value)) / 60
                #expect(row == own || row == own + 1)
            }
        }
    }
}
