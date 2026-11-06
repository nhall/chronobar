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
          day [<date>]      List a Day's labels and totals; <date> is YYYY-MM-DD, else today.
          summary           Show today, yesterday, this week and this month.
          labels [<query>]  List the suggested labels, or those containing <query>.
          pin <label>       Keep <label> in the suggestions.
          archive <label>   Unpin <label> and hide it from the suggestions, keeping its time.
          help              Show this help.

        Options:
          --json            Print the app's JSON response instead of text.
          --dev             Talk to the development copy (Chronobar Dev) instead of Chronobar.
          --                End of options: everything after it is the label.

        The words after a command are joined into one label or query, so quotes are optional.
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
        case "day":
            guard words.count <= 2 else { throw OperationError(.usage, "day takes one date, YYYY-MM-DD.") }
            request = .day(date: rest.isEmpty ? nil : rest)
        case "summary":
            guard rest.isEmpty else { throw OperationError(.usage, "summary takes no arguments.") }
            request = .summary
        case "labels": request = .labels(query: rest.isEmpty ? nil : rest)
        case "pin", "archive":
            guard !rest.isEmpty else { throw OperationError(.usage, "\(command) needs a label.") }
            request = command == "pin" ? .pin(label: rest) : .archive(label: rest)
        default: throw OperationError(.usage, "Unknown command \(command).")
        }
        self = .request(request, json: json, copy: copy)
    }
}
