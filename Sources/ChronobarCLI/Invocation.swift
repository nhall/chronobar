import Foundation
import ChronobarCore
import ChronobarOperations

/// What the command line asked for.
enum Invocation: Equatable {
    case help
    case request(Request, json: Bool, copy: BuildVariant.Copy)
    /// Run the MCP server on standard input and output, forwarding to `copy`.
    case mcp(copy: BuildVariant.Copy)

    static let usage = """
        Usage: chronobar [--json] [--dev] <command>

        Commands:
          status                        List the running timers and today's totals.
          start <label>                 Start a timer for <label>, or keep the one it has.
          stop [<label>] [--at TIME]    Stop <label>'s timer, now or back at TIME; with no
                                        label, the only running one.
          set-start [<label>] --at TIME Move the start of <label>'s timer (or the only
                                        running one) to TIME.
          add <label> --start TIME --end TIME
                                        Add a finished entry, without starting a timer.
          add <label> --duration D [--day DAY]
                                        Add D (1:30, or 45 minutes) to <label> on DAY.
          adjust <label> <T> [--day DAY]
                                        Set <label>'s total on DAY to T (1:15) or change it
                                        (+15, -10).
          day [<date>]                  List a Day's labels and totals; <date> is YYYY-MM-DD,
                                        else today.
          summary                       Show today, yesterday, this week and this month.
          labels [<query>]              List the suggested labels, or those containing <query>.
          pin <label>                   Keep <label> in the suggestions.
          archive <label>               Unpin <label> and hide it from the suggestions, keeping
                                        its time.
          mcp                           Run an MCP server on standard input and output, with
                                        a tool for each command, for an agent to launch.
          help                          Show this help.

        Options:
          --json            Print the app's JSON response instead of text.
          --dev             Talk to the development copy (Chronobar Dev) instead of Chronobar.
          --                End of options: everything after it is the label.

        TIME is HH:MM today in local time, or ISO 8601 with an offset
        (2026-11-03T14:40:00-05:00). DAY is YYYY-MM-DD and defaults to today.
        The words after a command are joined into one label or query, so quotes are optional.
        Chronobar is launched if it isn't running. Exit status: 0 done, 1 refused,
        2 usage error, 3 Chronobar couldn't be reached.
        """

    /// The options that take a value, and the commands that take each.
    private static let valueOptions: [String: Set<String>] = [
        "--at": ["stop", "set-start"],
        "--start": ["add"], "--end": ["add"], "--duration": ["add"],
        "--day": ["add", "adjust"],
    ]

    /// Reads `arguments` (without the program name), with `now` and `calendar` giving today for `HH:MM`
    /// and for no `--day`. Throws a `usage` error for anything it doesn't take.
    init(_ arguments: [String], now: Date = Date(), calendar: Calendar = .current) throws(OperationError) {
        var json = false
        var copy = BuildVariant.Copy.everyday
        var words: [String] = []
        var values: [String: String] = [:]
        var optionsEnded = false
        var remaining = arguments[...]
        while let argument = remaining.popFirst() {
            // A word such as `-10` is an adjust, not an option.
            if optionsEnded || !argument.hasPrefix("-") || argument.dropFirst().first?.isNumber == true {
                words.append(argument)
                continue
            }
            let parts = argument.split(separator: "=", maxSplits: 1).map(String.init)
            if Self.valueOptions[parts[0]] != nil {
                guard let value = parts.count == 2 ? parts[1] : remaining.popFirst() else {
                    throw OperationError(.usage, "\(parts[0]) needs a value.")
                }
                values[parts[0]] = value
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
        for option in values.keys.sorted() where !Self.valueOptions[option]!.contains(command) {
            throw OperationError(.usage, "\(command) doesn't take \(option).")
        }
        var rest = Array(words.dropFirst())
        let label = rest.joined(separator: " ")

        func time(_ option: String) throws(OperationError) -> Date? {
            guard let text = values[option] else { return nil }
            guard let date = TimeArgument.parse(text, now: now, calendar: calendar) else {
                throw OperationError(.usage, "\(option) \(text) isn't a time: give HH:MM, or ISO 8601 with an offset.")
            }
            return date
        }
        // Checked by the app, as for `day`.
        let date = values["--day"]

        let request: Request
        switch command {
        case "help": self = .help; return
        case "mcp":
            guard rest.isEmpty, !json else { throw OperationError(.usage, "mcp takes no arguments other than --dev.") }
            self = .mcp(copy: copy)
            return
        case "status":
            guard label.isEmpty else { throw OperationError(.usage, "status takes no label.") }
            request = .status
        case "start":
            guard !label.isEmpty else { throw OperationError(.usage, "start needs a label.") }
            request = .start(label: label)
        case "stop": request = .stop(label: label.isEmpty ? nil : label, at: try time("--at"))
        case "set-start":
            guard let start = try time("--at") else { throw OperationError(.usage, "set-start needs --at TIME.") }
            request = .setStart(label: label.isEmpty ? nil : label, at: start)
        case "add":
            guard !label.isEmpty else { throw OperationError(.usage, "add needs a label.") }
            let start = try time("--start"), end = try time("--end")
            switch (start, end, values["--duration"]) {
            case (let start?, let end?, nil) where date == nil:
                request = .addEntry(label: label, span: .times(start: start, end: end))
            case (nil, nil, let duration?):
                request = .addEntry(label: label, span: .duration(duration, date: date))
            default:
                throw OperationError(.usage, "add needs --start and --end, or --duration with an optional --day.")
            }
        case "adjust":
            guard rest.count >= 2, let input = rest.popLast() else {
                throw OperationError(.usage, "adjust needs a label and a total such as 1:15, +15 or -10.")
            }
            request = .adjust(label: rest.joined(separator: " "), input: input, date: date)
        case "day":
            guard words.count <= 2 else { throw OperationError(.usage, "day takes one date, YYYY-MM-DD.") }
            request = .day(date: label.isEmpty ? nil : label)
        case "summary":
            guard label.isEmpty else { throw OperationError(.usage, "summary takes no arguments.") }
            request = .summary
        case "labels": request = .labels(query: label.isEmpty ? nil : label)
        case "pin", "archive":
            guard !label.isEmpty else { throw OperationError(.usage, "\(command) needs a label.") }
            request = command == "pin" ? .pin(label: label) : .archive(label: label)
        default: throw OperationError(.usage, "Unknown command \(command).")
        }
        self = .request(request, json: json, copy: copy)
    }
}
