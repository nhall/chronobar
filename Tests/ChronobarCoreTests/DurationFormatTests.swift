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

/// What VoiceOver reads for a total, the same minutes as `h:mm` in words.
private let spokenExamples: [(TimeInterval, String)] = [
    (0, "0 minutes"),
    (60, "1 minute"),
    (45 * 60 + 59, "45 minutes"),
    (3600, "1 hour"),
    (83 * 60, "1 hour 23 minutes"),
    (2 * 3600 + 60, "2 hours 1 minute"),
    (-600, "0 minutes"),
]

@Suite struct SpokenDurationTests {
    @Test(arguments: spokenExamples)
    func readsHoursAndMinutesInWords(seconds: TimeInterval, expected: String) {
        #expect(DurationFormat.spoken(seconds) == expected)
    }
}
