import Foundation
import Testing
import ChronobarCore

private let examples: [(TimeInterval, String)] = [
    (0, "0:00"),
    (59, "0:00"),
    (60, "0:01"),
    (83 * 60 + 59, "1:23"),
    (12 * 3600 + 5 * 60, "12:05"),
    (100 * 3600, "100:00"),
]

@Suite struct DurationFormatTests {
    @Test(arguments: examples)
    func formatsHoursAndMinutesRoundedDown(seconds: TimeInterval, expected: String) {
        #expect(DurationFormat.hoursMinutes(seconds) == expected)
    }

    @Test func clampsNegativeToZero() {
        #expect(DurationFormat.hoursMinutes(-600) == "0:00")
    }
}
