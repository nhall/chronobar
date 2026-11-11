import Foundation
import Testing
import ChronobarCore
import ChronobarOperations
@testable import ChronobarCLI

/// The correction commands' arguments: times as `HH:MM` today or ISO 8601, and the request they send.
@Suite struct CorrectionArgumentsTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()
    /// 2026-11-03T09:00:00-05:00.
    let now = Date(timeIntervalSince1970: 1_793_714_400)

    private func time(_ hour: Int, _ minute: Int, day: Int = 3) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func request(_ arguments: String...) throws -> Request {
        guard case .request(let request, _, _) = try Invocation(arguments, now: now, calendar: calendar) else {
            throw Unexpected()
        }
        return request
    }

    private func usageError(_ arguments: String...) -> OperationError? {
        do {
            _ = try Invocation(arguments, now: now, calendar: calendar)
            return nil
        } catch {
            return error
        }
    }

    @Test func hoursAndMinutesAreTodayInLocalTime() {
        #expect(TimeArgument.parse("14:40", now: now, calendar: calendar) == time(14, 40))
        #expect(TimeArgument.parse("8:05", now: now, calendar: calendar) == time(8, 5))
        #expect(TimeArgument.parse("00:00", now: now, calendar: calendar) == time(0, 0))
    }

    @Test func anISOTimeWithAnOffsetIsTakenAsIs() {
        #expect(TimeArgument.parse("2026-11-02T23:15:00-05:00", now: now, calendar: calendar) == time(23, 15, day: 2))
        #expect(TimeArgument.parse("2026-11-03T04:15:00Z", now: now, calendar: calendar) == time(23, 15, day: 2))
    }

    @Test(arguments: ["24:00", "9:60", "940", "+9:40", "9:4", "2026-11-03T09:40:00", "soon"])
    func anythingElseIsNotATime(text: String) {
        #expect(TimeArgument.parse(text, now: now, calendar: calendar) == nil)
    }

    @Test func stopTakesATime() throws {
        #expect(try request("stop", "--at", "8:30") == .stop(label: nil, at: time(8, 30)))
        #expect(try request("stop", "Website", "Redesign", "--at=08:30") == .stop(label: "Website Redesign", at: time(8, 30)))
        #expect(try request("stop", "Website Redesign") == .stop(label: "Website Redesign"))
    }

    @Test func setStartNeedsATime() throws {
        #expect(try request("set-start", "--at", "13:15") == .setStart(label: nil, at: time(13, 15)))
        #expect(try request("set-start", "Website Redesign", "--at", "13:15")
                == .setStart(label: "Website Redesign", at: time(13, 15)))
        #expect(usageError("set-start", "Website Redesign")?.kind == .usage)
    }

    @Test func addTakesAStartAndEndOrADuration() throws {
        #expect(try request("add", "Internal", "--start", "7:00", "--end", "7:45")
                == .addEntry(label: "Internal", span: .times(start: time(7, 0), end: time(7, 45))))
        #expect(try request("add", "Internal", "--duration", "1:30")
                == .addEntry(label: "Internal", span: .duration("1:30", date: nil)))
        #expect(try request("add", "Internal", "--duration", "45", "--day", "2026-11-02")
                == .addEntry(label: "Internal", span: .duration("45", date: "2026-11-02")))
    }

    @Test(arguments: [
        ["add", "Internal"],
        ["add", "Internal", "--start", "7:00"],
        ["add", "Internal", "--start", "7:00", "--end", "7:45", "--duration", "45"],
        ["add", "Internal", "--start", "7:00", "--end", "7:45", "--day", "2026-11-02"],
        ["add", "--duration", "45"],
        ["stop", "--at", "soon"],
        ["stop", "--at"],
        ["start", "Internal", "--at", "7:00"],
        ["status", "--day", "2026-11-02"],
    ])
    func wrongArgumentsAreAUsageError(arguments: [String]) {
        #expect((try? Invocation(arguments, now: now, calendar: calendar)) == nil)
    }

    @Test func adjustTakesTheLastWordAsTheTotalOrChange() throws {
        #expect(try request("adjust", "Client A, Ticket 665", "1:15")
                == .adjust(label: "Client A, Ticket 665", input: "1:15"))
        #expect(try request("adjust", "Internal", "-10") == .adjust(label: "Internal", input: "-10"))
        #expect(try request("adjust", "Internal", "+15", "--day", "2026-11-02")
                == .adjust(label: "Internal", input: "+15", date: "2026-11-02"))
        #expect(usageError("adjust", "1:15")?.kind == .usage)
    }

    @Test func relabelTakesTheWordsAfterToAsTheNewLabel() throws {
        #expect(try request("relabel", "Northwnd,", "Ticket", "665", "--to", "Northwind,", "Ticket", "665")
                == .relabel(label: "Northwnd, Ticket 665", newLabel: "Northwind, Ticket 665"))
        #expect(try request("relabel", "Northwnd", "--to=Northwind,", "Ticket", "665", "--day", "2026-11-02")
                == .relabel(label: "Northwnd", newLabel: "Northwind, Ticket 665", date: "2026-11-02"))
        #expect(try request("relabel", "--day=2026-11-02", "Northwnd", "--to", "Northwind")
                == .relabel(label: "Northwnd", newLabel: "Northwind", date: "2026-11-02"))
        #expect(try request("relabel", "Northwnd", "--to", "Ticket", "-10", "--json")
                == .relabel(label: "Northwnd", newLabel: "Ticket -10"))
        #expect(try request("relabel", "Northwnd", "--to", "--", "--draft")
                == .relabel(label: "Northwnd", newLabel: "--draft"))
    }

    @Test(arguments: [
        ["relabel", "Northwnd"],
        ["relabel", "--to", "Northwind"],
        ["relabel", "Northwnd", "--to"],
        ["relabel", "Northwnd", "--to", "--day", "2026-11-02"],
        ["adjust", "Internal", "1:15", "--to", "Overhead"],
    ])
    func relabelNeedsALabelAndANewLabel(arguments: [String]) {
        #expect((try? Invocation(arguments, now: now, calendar: calendar)) == nil)
    }
}

private struct Unexpected: Error {}
