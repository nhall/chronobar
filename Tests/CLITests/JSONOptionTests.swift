import Foundation
import Testing
import ChronobarCore
import ChronobarOperations
@testable import ChronobarCLI

/// `--json` counts only where it is read as an option: not after `--`, nor as another option's value. A
/// command line that doesn't parse still answers in JSON when it asked for it.
@Suite struct JSONOptionTests {
    @Test func jsonAfterTheEndOfOptionsIsPartOfTheLabel() throws {
        #expect(try Invocation(["start", "--", "--json"]) == .request(.start(label: "--json"), json: false, copy: .everyday))
        #expect(!Invocation.asksForJSON(["start", "--", "--json"]))
    }

    @Test func jsonAsAnOptionsValueIsNotTheOption() {
        #expect(!Invocation.asksForJSON(["stop", "--at", "--json"]))
    }

    @Test func aCommandLineThatDoesntParseStillAsksForJSON() {
        #expect(throws: OperationError.self) { try Invocation(["--bogus", "--json", "status"]) }
        #expect(Invocation.asksForJSON(["--bogus", "--json", "status"]))
        #expect(Invocation.asksForJSON(["--json", "frobnicate"]))
    }
}
