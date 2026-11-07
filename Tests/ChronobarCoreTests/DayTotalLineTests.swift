import Foundation
import Testing
import ChronobarCore

/// The Panel's "Total" line between the Week strip and the rows, and the (i) Time Summary's lines: the
/// total, then the clock time, and one VoiceOver element for both.
@Suite struct DayTotalLineTests {
    @Test func showsTheTotalThenTheClockTime() {
        let line = DayTotalLine(total: 197 * 60, elapsed: 180 * 60)
        #expect(line.text == "Total 3:17 · Clock time 3:00")
    }

    @Test func voiceOverReadsTheLineAsOneInWords() {
        let line = DayTotalLine(total: 197 * 60, elapsed: 180 * 60)
        #expect(line.accessibilityLabel == "Total 3 hours 17 minutes, clock time 3 hours")
    }

    @Test func theHelpTagSaysWhatClockTimeCounts() {
        let line = DayTotalLine(total: 20 * 60, elapsed: 10 * 60)
        #expect(line.help == "Total adds up every Label's time. Clock time counts the time when any timer was "
                + "running, overlapping timers once, and doesn't include time logged by hand.")
    }

    @Test func aTimeSummaryLineKeepsItsPeriodsName() {
        let line = DayTotalLine("This week", total: 197 * 60, elapsed: 180 * 60)
        #expect(line.text == "This week 3:17 · Clock time 3:00")
        #expect(line.accessibilityLabel == "This week 3 hours 17 minutes, clock time 3 hours")
    }

    @Test func theWidestDayReadsInFull() {
        let line = DayTotalLine(total: 86_399, elapsed: 86_399)
        #expect(line.text == "Total 23:59 · Clock time 23:59")
    }
}
