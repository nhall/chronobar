import MCP

/// The tools `chronobar mcp` lists: one per operation, named as the operation is on the wire, so a tool's
/// arguments are the request's keys.
enum MCPTools {
    static let all: [Tool] = [
        Tool(name: "status", title: "Running timers",
             description: "What is being timed right now: each running timer (Label, start, source, the Label's "
                 + "total today), with today's Day total and clock time (elapsed_seconds: the time when any timer "
                 + "ran, overlaps counted once, without time logged by hand). For every Label with time today, "
                 + "stopped ones too, call day; for a week, week; for today, yesterday, this week and this month "
                 + "at once, summary.",
             inputSchema: schema([:]), annotations: reading),
        Tool(name: "start", title: "Start a timer",
             description: "Start a timer for a Label, such as \"Client A, Ticket 665\". If the Label's timer is "
                 + "already running it keeps going (already_running is true); there is never a second timer for a "
                 + "Label. Other timers keep running unless the user has set starting to pause them (they are "
                 + "listed in paused). This session remembers the Labels it starts, not one that was already "
                 + "running: stop and set_start without a label act on them.",
             inputSchema: schema(["label": label("The Label to time. Matched to an existing Label ignoring case.")],
                                 required: ["label"]),
             annotations: changing(idempotent: true)),
        Tool(name: "stop", title: "Stop a timer",
             description: "Stop a timer, now or back at an earlier time, and return the Entry as stored with the "
                 + "Label's new total. Without a label, stops the timer this session started; if this session "
                 + "started several that are running, or none, nothing changes and the error lists the running "
                 + "timers, so ask the user which one or name it. Closing the session leaves its timers running.",
             inputSchema: schema(["label": label("The Label whose timer to stop. Leave out for this session's timer."),
                                  "at": time("When the work stopped, if earlier than now. Not in the future.")]),
             annotations: changing(destructive: true)),
        Tool(name: "set_start", title: "Move a timer's start",
             description: "Move the start of a running timer, for example when the user says they actually "
                 + "started at 1:15. It may reach back across midnight. Without a label, acts on the timer this "
                 + "session started, as stop does.",
             inputSchema: schema(["label": label("The Label whose timer to move. Leave out for this session's timer."),
                                  "at": time("The new start. Not in the future.")],
                                 required: ["at"]),
             annotations: changing(destructive: true)),
        Tool(name: "add_entry", title: "Add a line item",
             description: "Add finished time for a Label without starting a timer. Give either start and end (a "
                 + "timed Entry, split at midnight if it crosses one) or duration with an optional date (time "
                 + "added to that Day's total). Refused if it is in the future, if end isn't after start, or if "
                 + "the Label already has time in that stretch.",
             inputSchema: schema(["label": label("The Label to add the time to."),
                                  "start": time("When the work started. Give with end."),
                                  "end": time("When the work ended. Give with start."),
                                  "duration": duration("How long, such as 1:30 or 45 (minutes). Instead of start and end."),
                                  "date": date("The Day to add duration to; today if left out. Only with duration.")],
                                 required: ["label"]),
             annotations: changing()),
        Tool(name: "adjust", title: "Adjust a total",
             description: "Set a Label's total on a Day (1:15) or change it (+15, -10 minutes), by adding a manual "
                 + "Entry for the difference.",
             inputSchema: schema(["label": label("The Label whose total to change."),
                                  "input": duration("The new total, such as 1:15, or a change, such as +15 or -10."),
                                  "date": date("The Day; today if left out.")],
                                 required: ["label", "input"]),
             annotations: changing(destructive: true)),
        Tool(name: "relabel", title: "Relabel a row",
             description: "Move all of a Label's time on a Day (timed Entries, line items and adjustments) to "
                 + "another Label, for example to fix a typo or file the time under a more specific Label. Other "
                 + "Days keep the old Label. A running timer keeps running under the new Label, with the same "
                 + "start, and stays this session's if this session started it. Returns the new Label as stored, "
                 + "its finished Entries, its timer if one runs, its total, and the Day's totals, which don't "
                 + "change. Into a Label that already has time that Day, the two rows merge; refused if their "
                 + "timed Entries overlap, which would count that time twice, or if the new Label's timer is "
                 + "running that Day. A change of capitals or spaces only is kept, also in the pinned or "
                 + "archived list. A timer running since before midnight moves whole, with its time on the "
                 + "earlier Days.",
             inputSchema: schema(["label": label("The Label whose row to move."),
                                  "new_label": label("The Label to move the time to. Matched to an existing Label "
                                                     + "ignoring case."),
                                  "date": date("The Day; today if left out.")],
                                 required: ["label", "new_label"]),
             annotations: changing(destructive: true)),
        Tool(name: "day", title: "A Day's rows",
             description: "Every Label with time on one Day (today if date is left out), each with its total "
                 + "and, today, whether its timer is running, plus the Day's total and clock time "
                 + "(elapsed_seconds). Use it for what was worked on a given Day, or to find a row before adjust "
                 + "or relabel. For several Days call week; for only what is running now, status.",
             inputSchema: schema(["date": date("The Day; today if left out.")]),
             annotations: reading),
        Tool(name: "week", title: "A week's totals",
             description: "One week, starting on the user's first weekday: the week containing date (this week "
                 + "if left out; any date in last week for last week). Returns each Day's total and clock time "
                 + "(elapsed_seconds), each Label's total across the week, and the week's totals. Use it for "
                 + "time spent on a Label this week or last; for one Day's Labels call day, and for the week's "
                 + "total beside today's and the month's, summary.",
             inputSchema: schema(["date": date("Any Day in the week; today if left out.")]),
             annotations: reading),
        Tool(name: "summary", title: "Time Summary",
             description: "Four totals at once, across every Label: today, yesterday, this week (as week counts "
                 + "it) and this calendar month, each with its clock time (elapsed_seconds). Takes no arguments. "
                 + "Use it for how much was tracked over these periods; it has no per-Label figures, so for those "
                 + "call day or week.",
             inputSchema: schema([:]), annotations: reading),
        Tool(name: "labels", title: "Find Labels",
             description: "The Labels the user is likely to mean: the suggestions (Labels used in the last 30 "
                 + "days, plus pinned ones, minus archived ones; the same list the Panel suggests), or, with "
                 + "query, every Label containing that text. Call it before start, add_entry or relabel when the "
                 + "user names work loosely, such as \"the Northwind ticket\", to use the Label as stored. With a "
                 + "query, match says whether the text names a suggested, archived, unused or new Label. Changes "
                 + "nothing.",
             inputSchema: schema(["query": .object(["type": "string",
                                                    "description": "Text the Labels should contain, ignoring case."])]),
             annotations: reading),
        Tool(name: "archive", title: "Archive a Label",
             description: "Unpin a Label and hide it from the suggestions, keeping all its time. Starting it again "
                 + "brings it back.",
             inputSchema: schema(["label": label("The Label to archive.")], required: ["label"]),
             annotations: changing(idempotent: true)),
        Tool(name: "pin", title: "Pin a Label",
             description: "Keep a Label in the suggestions (what labels lists and the Panel suggests) however "
                 + "long since it was used, for work the user returns to now and then. An archived Label is "
                 + "brought back. Its time doesn't change, and pinning a pinned Label changes nothing. The "
                 + "opposite is archive.",
             inputSchema: schema(["label": label("The Label to pin.")], required: ["label"]),
             annotations: changing(idempotent: true)),
    ]

    private static func schema(_ properties: [String: Value], required: [String] = []) -> Value {
        .object(["type": "object", "properties": .object(properties),
                 "required": .array(required.map { .string($0) }), "additionalProperties": false])
    }

    private static func label(_ description: String) -> Value {
        .object(["type": "string", "minLength": 1, "description": .string(description)])
    }

    private static func time(_ description: String) -> Value {
        .object(["type": "string", "format": "date-time",
                 "description": .string(description + " ISO 8601 with an offset, such as 2026-11-03T14:40:00-05:00.")])
    }

    private static func date(_ description: String) -> Value {
        .object(["type": "string", "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
                 "description": .string(description + " YYYY-MM-DD.")])
    }

    private static func duration(_ description: String) -> Value {
        .object(["type": "string", "description": .string(description)])
    }

    private static let reading = Tool.Annotations(readOnlyHint: true, openWorldHint: false)

    private static func changing(idempotent: Bool = false, destructive: Bool = false) -> Tool.Annotations {
        Tool.Annotations(readOnlyHint: false, destructiveHint: destructive, idempotentHint: idempotent, openWorldHint: false)
    }
}
