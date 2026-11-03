import Foundation
import Testing
import ChronobarCore

private let valid: [(String, DurationInput)] = [
    ("1:30", .absolute(seconds: 90 * 60)),
    ("45", .absolute(seconds: 45 * 60)),
    ("0:15", .absolute(seconds: 15 * 60)),
    ("0", .absolute(seconds: 0)),
    ("12:05", .absolute(seconds: 725 * 60)),
    ("90", .absolute(seconds: 90 * 60)),
    (" 1:15 ", .absolute(seconds: 75 * 60)),
    ("+15", .relative(seconds: 15 * 60)),
    ("-10", .relative(seconds: -10 * 60)),
    ("+1:00", .relative(seconds: 60 * 60)),
    ("-0:30", .relative(seconds: -30 * 60)),
]

private let invalid: [String] = [
    "", "  ", "+", "-", "abc", "1:", ":30", "1:5", "1:60", "1:300", "1:30:00", "1.5", "1h", "+-5", "--5",
    "1 30", "١٥", "999999",
]

@Suite struct DurationInputTests {
    @Test(arguments: valid)
    func parses(text: String, expected: DurationInput) throws {
        #expect(try DurationInput(parsing: text) == expected)
    }

    @Test(arguments: invalid)
    func rejects(text: String) {
        #expect(throws: InvalidDuration(text: text)) { try DurationInput(parsing: text) }
    }
}
