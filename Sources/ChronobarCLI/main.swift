import Foundation
import ChronobarCore
import ChronobarOperations

/// `chronobar`: sends one operation to the running app over its socket and prints the answer, as text or
/// with `--json` as the app's JSON response. The app does the work; this never touches the data folder.

enum ExitCode {
    static let done: Int32 = 0
    static let refused: Int32 = 1
    static let usage: Int32 = 2
    static let unreachable: Int32 = 3

    static func of(_ error: OperationError) -> Int32 {
        switch error.kind {
        case .usage: usage
        case .appUnreachable: unreachable
        default: refused
        }
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
let json = arguments.contains("--json")

func fail(_ error: OperationError) -> Never {
    if json {
        FileHandle.standardOutput.write(Wire.encode(.failure(error), timeZone: .current))
    } else {
        FileHandle.standardError.write(Data("chronobar: \(error.message)\n".utf8))
        if error.kind == .usage { FileHandle.standardError.write(Data((Invocation.usage + "\n").utf8)) }
    }
    exit(ExitCode.of(error))
}

func run() throws(OperationError) {
    switch try Invocation(arguments) {
    case .help:
        print(Invocation.usage)
    case .request(let request, let json, let copy):
        let client = try connect(to: copy)
        let reply: Data
        do {
            reply = try client.send(line: Wire.encode(request))
        } catch {
            throw OperationError(.appUnreachable, "\(copy.name) didn't answer: \(error)")
        }
        let response: Response
        do {
            response = try Wire.response(from: reply)
        } catch {
            throw OperationError(.failed, "\(copy.name) sent an answer this command can't read: \(error)")
        }
        switch response {
        case .success(let result):
            if json {
                FileHandle.standardOutput.write(reply + Data("\n".utf8))
            } else {
                print(Output.text(result))
            }
        case .failure(let error):
            fail(error)
        }
    }
}

do {
    try run()
} catch {
    fail(error)
}
