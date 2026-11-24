// Temporary: how this macOS's Foundation finds Day boundaries when Havana's midnight repeats.
import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/Havana")!
let iso = ISO8601DateFormatter()
iso.timeZone = calendar.timeZone
iso.formatOptions = [.withInternetDateTime]

func noon(_ d: Int, _ m: Int) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: m, day: d, hour: 12))!
}

print("tzdata", TimeZone.timeZoneDataVersion)
for (d, m) in [(31, 10), (1, 11), (2, 11)] {
    let n = noon(d, m)
    let i = calendar.dateInterval(of: .day, for: n)!
    print("\(m)-\(d)", "startOfDay", iso.string(from: calendar.startOfDay(for: n)),
          "interval", iso.string(from: i.start), "→", iso.string(from: i.end), i.duration / 3600)
}
let firstMidnight = iso.date(from: "2026-11-01T00:00:00-04:00")!
let comps = calendar.dateComponents([.year, .month, .day], from: firstMidnight)
print("first midnight is day", comps.month!, comps.day!)
