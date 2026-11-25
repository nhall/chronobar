import MCP

/// Each tool's output schema: the shape of its structured result, which is the operation's result as the
/// socket and `chronobar --json` give it (`Wire`). Keys are snake_case; times are ISO 8601 with an offset;
/// totals are whole seconds or minutes. A field the result leaves out when it has no value (match, manual,
/// a relabel's timer) is optional, never null.
///
/// Built from the same pieces as the result types in ChronobarOperations, field for field. The MCP tests
/// run every tool and check each result against its schema, so a result type that changes without its
/// schema fails them.
enum MCPOutputSchemas {
    static let byTool: [String: Value] = [
        "status": object([
            "timers": array(timer, "The running timers, in the order they started."),
            "today": day,
        ]),
        "start": object([
            "timer": timer,
            "already_running": boolean("Whether the Label's timer was already running, so nothing changed."),
            "paused": array(entry, "Timers this start paused, when the user has set starting to pause the others."),
            "today": day,
        ]),
        "stop": object([
            "entry": entry,
            "running": array(timer, "The timers still running."),
            "today": day,
        ]),
        "set_start": object([
            "timer": timer,
            "earlier": array(entry, "For a start before today's midnight, the finished Entries the run now has "
                             + "on the Days before, oldest first; otherwise empty."),
            "today": day,
        ]),
        "add_entry": object([
            "label": string("The Label as stored."),
            "entries": array(entry, "For start and end, the timed Entries stored, one per Day, oldest first; "
                             + "else empty."),
            "manual": manualEntry,
            "days": array(day, "The totals of each Day written, oldest first."),
        ], optional: ["manual"]),
        "adjust": object([
            "label": string("The Label as stored."),
            "date": date("The Day adjusted."),
            "change_seconds": integer("How much the Label's total changed; 0 if it already had that total."),
            "total_seconds": integer("The Label's new total on that Day."),
            "day": day,
        ]),
        "relabel": object([
            "old_label": string("The old Label as its row showed it."),
            "label": string("The new Label as stored."),
            "date": date("The Day relabeled."),
            "entries": array(entry, "The finished timed Entries now under the new Label that Day, oldest first."),
            "total_seconds": integer("The new Label's total that Day."),
            "day": day,
            "timer": timer,
        ], optional: ["timer"]),
        "day": object([
            "day": day,
            "rows": array(row, "One per Label with Entries that Day, in the order each first appears."),
            "malformed": boolean("Whether the Day file won't parse, so it reads as empty."),
        ]),
        "week": object([
            "first": date("The week's first Day."),
            "last": date("The week's last Day."),
            "total_seconds": integer("The sum of the Days' totals."),
            "total_minutes": integer("The sum of the Days' total_minutes."),
            "elapsed_seconds": integer("The sum of the Days' clock time."),
            "elapsed_minutes": integer("The sum of the Days' elapsed_minutes."),
            "days": array(day, "Each of the seven Days, first to last."),
            "labels": array(labelTotal, "One per Label with Entries that week, in the order each first appears."),
            "malformed": array(date("A Day whose file won't parse."), "The Days whose file won't parse."),
        ]),
        "summary": object([
            "today": period,
            "yesterday": period,
            "week": period,
            "month": period,
        ]),
        "labels": object([
            "labels": array(suggestion, "The suggestions containing the query, best match first."),
            "match": labelMatch,
        ], optional: ["match"]),
        "pin": object([
            "label": string("The Label as stored."),
            "already_pinned": boolean("Whether it was pinned before, so nothing changed."),
            "pinned": array(string("A Pinned Label."), "Every Pinned Label."),
        ]),
        "archive": object([
            "label": string("The Label as stored."),
            "already_archived": boolean("Whether it was archived before, so nothing changed."),
            "unpinned": boolean("Whether archiving took it off the Pinned Labels."),
            "running": boolean("Whether its timer runs; archiving leaves it running."),
        ]),
    ]

    // MARK: Shared parts

    /// `TimerResult`.
    private static let timer = object([
        "label": string("The Label as stored."),
        "start": time("When the timer started."),
        "source": source,
        "total_seconds": integer("The Label's total today, counted up to now."),
    ], "A running timer.")

    /// `EntryResult`.
    private static let entry = object([
        "label": string("The Label as stored."),
        "start": time("When the Entry starts."),
        "end": time("When the Entry ends."),
        "source": source,
        "total_seconds": integer("The Label's total on the Entry's Day, with this Entry."),
    ], "A timed Entry, as stored.")

    /// `DayResult`.
    private static let day = object([
        "date": date("The Day."),
        "total_seconds": integer("The Day total across every Label."),
        "total_minutes": integer("The Day total in whole minutes, as the Panel shows it."),
        "elapsed_seconds": integer("Clock time: when any timer ran, overlaps counted once, without time logged by hand."),
        "elapsed_minutes": integer("Clock time in whole minutes, as the Panel shows it."),
    ], "A Day's total and clock time.")

    /// `RowResult`.
    private static let row = object([
        "label": string("The Label as the row shows it."),
        "total_seconds": integer("The Label's total that Day; a running timer counted up to now."),
        "total_minutes": integer("The minutes the row shows, so the rows add up to the Day's total_minutes."),
        "running": boolean("Whether the Label's timer is running."),
    ], "One Label's row on a Day.")

    /// `PeriodResult`.
    private static let period = object([
        "first": date("The period's first Day."),
        "last": date("The period's last Day."),
        "total_seconds": integer("The sum of its Days' totals."),
        "elapsed_seconds": integer("The sum of its Days' clock time."),
    ], "A period's total and clock time.")

    /// `LabelTotalResult`.
    private static let labelTotal = object([
        "label": string("The Label."),
        "total_seconds": integer("The Label's total across the week."),
        "total_minutes": integer("The minutes the Label's week line shows."),
    ], "One Label's total across the week.")

    /// `ManualEntryResult`.
    private static let manualEntry = object([
        "date": date("The Day the duration was added to."),
        "seconds": integer("The duration added."),
        "total_seconds": integer("The Label's total that Day, with it."),
    ], "For a duration, the manual Entry stored; left out for start and end.")

    /// `LabelResult`.
    private static let suggestion = object([
        "label": string("The Label."),
        "pinned": boolean("Whether it is a Pinned Label."),
    ], "A suggested Label.")

    /// `LabelMatchResult`.
    private static let labelMatch = object([
        "kind": .object(["type": "string", "enum": ["suggested", "archived", "unused", "new"],
                         "description": "Whether the query names a suggested, archived, unused or new Label."]),
        "label": string("The existing Label; left out for a new one."),
    ], "The Label the query names exactly, ignoring case; left out without a query.", optional: ["label"])

    /// `EntrySource`.
    private static let source: Value = .object([
        "type": "string", "enum": ["app", "agent"],
        "description": "app: started in the app; agent: through MCP or the command line.",
    ])

    // MARK: Building

    /// An object with exactly `properties`, all required but `optional`.
    private static func object(_ properties: [String: Value], _ description: String? = nil,
                               optional: Set<String> = []) -> Value {
        var schema: [String: Value] = [
            "type": "object",
            "properties": .object(properties),
            "required": .array(properties.keys.filter { !optional.contains($0) }.sorted().map { .string($0) }),
            "additionalProperties": false,
        ]
        if let description { schema["description"] = .string(description) }
        return .object(schema)
    }

    private static func object(_ properties: [String: Value], optional: Set<String>) -> Value {
        object(properties, nil, optional: optional)
    }

    private static func array(_ items: Value, _ description: String) -> Value {
        .object(["type": "array", "items": items, "description": .string(description)])
    }

    private static func string(_ description: String) -> Value {
        .object(["type": "string", "description": .string(description)])
    }

    private static func integer(_ description: String) -> Value {
        .object(["type": "integer", "description": .string(description)])
    }

    private static func boolean(_ description: String) -> Value {
        .object(["type": "boolean", "description": .string(description)])
    }

    private static func time(_ description: String) -> Value {
        .object(["type": "string", "format": "date-time",
                 "description": .string(description + " ISO 8601 with an offset.")])
    }

    private static func date(_ description: String) -> Value {
        .object(["type": "string", "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
                 "description": .string(description + " YYYY-MM-DD.")])
    }
}
