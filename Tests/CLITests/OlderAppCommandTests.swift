import Foundation
import Testing
import ChronobarCore
import ChronobarOperations

/// The built `chronobar`, run against a fake app's socket (`CHRONOBAR_SOCKET`): what a script or a user
/// sees, on standard output and error and in the exit status, when the running app is another version.
@Suite(.serialized) struct OlderAppCommandTests {
    /// `status` as an app from before Day totals carried minutes answers it.
    static let olderStatus = #"{"ok":true,"op":"status","result":{"timers":[],"today":{"date":"2026-11-03","elapsed_seconds":0,"total_seconds":0}}}"#
    static let older = "The running Chronobar is older than this command. Quit Chronobar and run the command again."

    @Test func anOlderAppsReplySaysSoAndExitsOne() throws {
        let app = try FakeApp(reply: Data(Self.olderStatus.utf8))

        let run = try Command.run(["status"], socket: app.url)

        #expect(run.status == 1)
        #expect(run.output.isEmpty)
        #expect(run.error == "chronobar: \(Self.older)\n")
    }

    @Test func withJSONAnOlderAppsReplyIsPrintedAsItCameAndTheErrorGoesToStandardError() throws {
        let app = try FakeApp(reply: Data(Self.olderStatus.utf8))

        let run = try Command.run(["--json", "status"], socket: app.url)

        #expect(run.status == 0)
        #expect(run.output == Self.olderStatus + "\n")
        #expect(run.error == "chronobar: \(Self.older)\n")
    }

    @Test func withJSONARefusalOfAnotherVersionExitsAsItSays() throws {
        let newer = #"{"ok":false,"error":{"kind":"newer_kind","message":"Something new."}}"#
        let app = try FakeApp(reply: Data(newer.utf8))

        let run = try Command.run(["--json", "status"], socket: app.url)

        #expect(run.status == 1)
        #expect(run.output == newer + "\n")
        #expect(run.error == "chronobar: The running Chronobar is a different version from this command. "
                + "Quit Chronobar and run the command again.\n")
    }

    @Test func aReplyThatIsntJSONFailsWithoutBlamingTheVersion() throws {
        let app = try FakeApp(reply: Data("not json".utf8))

        let plain = try Command.run(["status"], socket: app.url)
        let json = try Command.run(["--json", "status"], socket: app.url)

        #expect(plain.status == 1)
        #expect(plain.error == "chronobar: Chronobar sent an answer this command can't read.\n")
        #expect(json.status == 1)
        let error = try #require(try JSONSerialization.jsonObject(with: Data(json.output.utf8)) as? [String: Any])
        #expect(error["ok"] as? Bool == false)
        #expect((error["error"] as? [String: Any])?["kind"] as? String == "failed")
    }

    @Test func aCurrentAppsReplyIsReadAsBefore() throws {
        let today = DayResult(date: "2026-11-03", totalSeconds: 197 * 60, totalMinutes: 197, elapsedSeconds: 180 * 60,
                              elapsedMinutes: 180)
        let line = Wire.encode(.success(.status(StatusResult(timers: [], today: today))), timeZone: .current)
        let app = try FakeApp(reply: line.dropLast())

        let run = try Command.run(["status"], socket: app.url)

        #expect(run.status == 0)
        #expect(run.output == "Nothing running.\n2026-11-03: Total 3:17 · Clock time 3:00\n")
        #expect(run.error.isEmpty)
    }

    /// With `CHRONOBAR_SOCKET` set the command never launches the app, so a test can't start the real one.
    @Test func withNothingListeningOnTheOverrideTheAppIsntLaunched() throws {
        let socket = URL(fileURLWithPath: "/tmp/cb-\(UUID().uuidString.prefix(8)).sock")
        let started = Date()

        let run = try Command.run(["status"], socket: socket)

        #expect(run.status == 3)
        #expect(run.error.hasPrefix("chronobar: Nothing answered on \(socket.path) (CHRONOBAR_SOCKET)"))
        // Launching waits up to 10 seconds for the app to listen; this didn't try.
        #expect(Date().timeIntervalSince(started) < 5)
    }

    /// `chronobar mcp` over standard input and output, as an agent's client runs it: the tool call is a
    /// tool error with the message for the user.
    @Test func overMCPAnOlderAppsReplyIsAToolErrorSayingSo() throws {
        let app = try FakeApp(reply: Data(Self.olderStatus.utf8))
        let messages = [
            #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1"}}}"#,
            #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#,
            #"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"status","arguments":{}}}"#,
        ]

        let replies = try Command.mcp(messages, socket: app.url, until: 2)

        let call = try #require(replies.first { $0["id"] as? Int == 2 }?["result"] as? [String: Any])
        #expect(call["isError"] as? Bool == true)
        let content = try #require(call["content"] as? [[String: Any]])
        #expect(content.first?["text"] as? String == Self.older)
    }
}
