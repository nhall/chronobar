import Foundation
import ChronobarCore
import ChronobarOperations

/// The app's answer to a request, as the command and `chronobar mcp` read it. An app that kept running
/// through an upgrade can be older than the command, and its replies can lack a field the command needs.
enum Reply {
    /// The response in `line`; `versionMismatch` if it won't decode, naming what to do about it.
    static func read(_ line: Data, from copy: BuildVariant.Copy) throws(OperationError) -> Response {
        do {
            return try Wire.response(from: line)
        } catch {
            throw OperationError(.versionMismatch, "The running \(copy.name) is older than this command. "
                                 + "Quit \(copy.name) and run the command again.")
        }
    }

    /// The exit status for `line` printed as it came, with `--json`, when `read` can't decode it: from its
    /// `ok` and a failure's `kind` alone, a kind this command doesn't know being a refusal. Nil for a line
    /// that isn't a reply at all.
    static func exitStatus(of line: Data) -> Int32? {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let ok = object["ok"] as? Bool else { return nil }
        if ok { return ExitCode.done }
        let kind = (object["error"] as? [String: Any])?["kind"] as? String
        return kind.flatMap(OperationError.Kind.init).map(ExitCode.of) ?? ExitCode.refused
    }
}
