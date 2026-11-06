import ChronobarCore
import ChronobarOperations

/// What the command line asked for.
enum Invocation: Equatable {
    case help
    case request(Request, json: Bool, copy: BuildVariant.Copy)

    static let usage = """
        Usage: chronobar [--json] [--dev] <command>

        Commands:
          status            List the running timers and today's totals.
          start <label>     Start a timer for <label>, or keep the one it has.
          stop [<label>]    Stop <label>'s timer; with no label, the only running one.
          help              Show this help.

        Options:
          --json            Print the app's JSON response instead of text.
          --dev             Talk to the development copy (Chronobar Dev) instead of Chronobar.
          --                End of options: everything after it is the label.

        The words after start or stop are joined into one label, so quotes are optional.
        Chronobar is launched if it isn't running. Exit status: 0 done, 1 refused,
        2 usage error, 3 Chronobar couldn't be reached.
        """

    /// Reads `arguments` (without the program name). Throws a `usage` error for anything it doesn't take.
    init(_ arguments: [String]) throws(OperationError) {
        var json = false
        var copy = BuildVariant.Copy.everyday
        var words: [String] = []
        var optionsEnded = false
        for argument in arguments {
            if optionsEnded || !argument.hasPrefix("-") {
                words.append(argument)
                continue
            }
            switch argument {
            case "--": optionsEnded = true
            case "--json": json = true
            case "--dev": copy = .development
            case "-h", "--help": self = .help; return
            default: throw OperationError(.usage, "Unknown option \(argument).")
            }
        }
        guard let command = words.first else { throw OperationError(.usage, "Name a command.") }
        let rest = words.dropFirst().joined(separator: " ")
        let request: Request
        switch command {
        case "help": self = .help; return
        case "status":
            guard rest.isEmpty else { throw OperationError(.usage, "status takes no label.") }
            request = .status
        case "start":
            guard !rest.isEmpty else { throw OperationError(.usage, "start needs a label.") }
            request = .start(label: rest)
        case "stop": request = .stop(label: rest.isEmpty ? nil : rest)
        default: throw OperationError(.usage, "Unknown command \(command).")
        }
        self = .request(request, json: json, copy: copy)
    }
}
