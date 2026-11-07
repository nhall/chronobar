import Foundation
import Testing
import ChronobarCore

/// The Panel's "Total" line between the Week strip and the rows: the Day total, then the elapsed time in
/// smaller text, and one VoiceOver element for both.
@Suite struct DayTotalLineTests {
    @Test func showsTheTotalAndTheElapsedTimeAfterIt() {
        let line = DayTotalLine(total: 177 * 60, elapsed: 170 * 60)
        #expect(line.label == "Total")
        #expect(line.total == "2:57")
        #expect(line.elapsed == "· 2:50 elapsed")
    }

    @Test func voiceOverReadsTheLineAsOneInWords() {
        let line = DayTotalLine(total: 20 * 60, elapsed: 10 * 60)
        #expect(line.accessibilityLabel == "Total for the day, 20 minutes, 10 minutes elapsed")
    }

    @Test func theHelpTagSaysWhatElapsedMeans() {
        let line = DayTotalLine(total: 20 * 60, elapsed: 10 * 60)
        #expect(line.help == "Total for the day · 0:10 elapsed, the clock time at least one timer ran")
    }

    @Test func theWidestDayReadsInFull() {
        let line = DayTotalLine(total: 86_399, elapsed: 86_399)
        #expect(line.total == "23:59")
        #expect(line.elapsed == "· 23:59 elapsed")
    }
}
