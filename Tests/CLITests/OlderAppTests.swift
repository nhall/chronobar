import Foundation
import Testing
import ChronobarCore
import ChronobarOperations
@testable import ChronobarCLI

/// After an upgrade the app still running can be older than the command, and its replies can lack a field
/// the command needs. The command says so, and what to do, rather than how decoding failed.
@Suite struct OlderAppTests {
    /// `status` as an app from before Day totals carried minutes answers it.
    let olderStatus = Data(#"""
        {"ok":true,"op":"status","result":{"timers":[],"today":{"date":"2026-11-03","elapsed_seconds":0,"total_seconds":0}}}
        """#.utf8)

    @Test func aReplyMissingAFieldSaysTheAppIsOlder() {
        #expect(throws: OperationError(.versionMismatch, "The running Chronobar is older than this command. "
                                       + "Quit Chronobar and run the command again.")) {
            try Reply.read(olderStatus, from: .everyday)
        }
    }

    @Test func theDevelopmentCopyIsNamed() {
        #expect(throws: OperationError(.versionMismatch, "The running Chronobar Dev is older than this command. "
                                       + "Quit Chronobar Dev and run the command again.")) {
            try Reply.read(olderStatus, from: .development)
        }
    }

    /// `--json` prints such a reply as it came, so it needs only `ok`, and a failure's `kind`, for the
    /// exit status.
    @Test func jsonTakesTheExitStatusFromAReplyThatWontDecode() {
        #expect(Reply.exitStatus(of: olderStatus) == 0)
        #expect(Reply.exitStatus(of: Data(#"{"ok":false,"error":{"kind":"not_running","message":"…"}}"#.utf8)) == 1)
        #expect(Reply.exitStatus(of: Data(#"{"ok":false,"error":{"kind":"usage","message":"…"}}"#.utf8)) == 2)
        // A kind this command doesn't know is still a refusal.
        #expect(Reply.exitStatus(of: Data(#"{"ok":false,"error":{"kind":"newer_kind"}}"#.utf8)) == 1)
    }

    @Test func aLineThatIsntAReplyHasNoExitStatus() {
        #expect(Reply.exitStatus(of: Data("not json".utf8)) == nil)
        #expect(Reply.exitStatus(of: Data(#"{"result":{}}"#.utf8)) == nil)
    }

    @Test func aReplyThatDecodesIsRead() throws {
        let line = Wire.encode(.failure(OperationError(.nothingRunning, "No timer is running.")), timeZone: .current)

        guard case .failure(let error) = try Reply.read(line, from: .everyday) else {
            Issue.record("The reply read as a success.")
            return
        }
        #expect(error.kind == .nothingRunning)
    }
}
