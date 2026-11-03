import Foundation

/// A typed duration: `1:30` or `45` (minutes) sets a total, `+15`, `-10` or `+1:00` changes it.
public enum DurationInput: Equatable, Sendable {
    case absolute(seconds: Int)
    case relative(seconds: Int)

    /// Reads `h:mm` (minutes 00–59) or whole minutes, with an optional leading `+` or `-`.
    /// Surrounding spaces are ignored. Anything else throws `InvalidDuration`.
    public init(parsing text: String) throws {
        var body = Substring(text.trimmingCharacters(in: .whitespaces))
        var sign: Int?
        if let first = body.first, first == "+" || first == "-" {
            sign = first == "+" ? 1 : -1
            body = body.dropFirst()
        }
        guard let minutes = Self.minutes(body) else { throw InvalidDuration(text: text) }
        if let sign {
            self = .relative(seconds: sign * minutes * 60)
        } else {
            self = .absolute(seconds: minutes * 60)
        }
    }

    /// Minutes in `h:mm` or `m`. Each part is at most 5 digits, so the seconds can't overflow.
    private static func minutes(_ text: Substring) -> Int? {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.allSatisfy({ (1...5).contains($0.count) && $0.allSatisfy { ("0"..."9").contains($0) } })
        else { return nil }
        switch parts.count {
        case 1:
            return Int(parts[0])
        case 2:
            guard parts[1].count == 2, let hours = Int(parts[0]), let minutes = Int(parts[1]), minutes < 60
            else { return nil }
            return hours * 60 + minutes
        default:
            return nil
        }
    }
}

/// Typed text that isn't a duration. The UI keeps the field as typed.
public struct InvalidDuration: Error, Equatable {
    public let text: String

    public init(text: String) { self.text = text }
}
