import MCP

/// The tools `chronobar mcp` lists: one per operation, named as the operation is on the wire, so a tool's
/// arguments are the request's keys.
enum MCPTools {
    static let all: [Tool] = [
        Tool(name: "status", title: "Running timers",
             description: "List the running timers (Label, start, source, the Label's total today) and today's "
                 + "Day total and clock time (elapsed_seconds: the time when any timer ran, overlaps counted "
                 + "once, without time logged by hand).",
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
        Tool(name: "day", title: "A Day's rows",
             description: "List a Day's Labels with their totals (and which are running, today), with the Day "
                 + "total and clock time (elapsed_seconds). For a question about a week, call week instead.",
             inputSchema: schema(["date": date("The Day; today if left out.")]),
             annotations: reading),
        Tool(name: "week", title: "A week's totals",
             description: "For the week containing a date (this week if left out), each Day's total and clock "
                 + "time (elapsed_seconds), each Label's total across the week, and the week's totals: what was "
                 + "spent on a Label this week or last.",
             inputSchema: schema(["date": date("Any Day in the week; today if left out.")]),
             annotations: reading),
        Tool(name: "summary", title: "Time Summary",
             description: "Today, yesterday, this week and this month: the total across every Label and the "
                 + "clock time (elapsed_seconds) for each.",
             inputSchema: schema([:]), annotations: reading),
        Tool(name: "labels", title: "Find Labels",
             description: "List the suggested Labels (used in the last 30 days, plus pinned ones, minus archived "
                 + "ones), or those containing query, to resolve what the user said to the Label stored. With a "
                 + "query, match says whether it names a suggested, archived, unused or new Label.",
             inputSchema: schema(["query": .object(["type": "string",
                                                    "description": "Text the Labels should contain, ignoring case."])]),
             annotations: reading),
        Tool(name: "archive", title: "Archive a Label",
             description: "Unpin a Label and hide it from the suggestions, keeping all its time. Starting it again "
                 + "brings it back.",
             inputSchema: schema(["label": label("The Label to archive.")], required: ["label"]),
             annotations: changing(idempotent: true)),
        Tool(name: "pin", title: "Pin a Label",
             description: "Keep a Label in the suggestions however long since it was used.",
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
