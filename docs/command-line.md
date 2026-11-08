# The command line

Every `chronobar` command, its rules, its JSON output and its exit status, for scripts and hooks.
[Back to the README](../README.md)

```sh
chronobar start "Northwind, Ticket 665"
chronobar status
chronobar stop --at 14:40          # the only running timer, back when the work finished
chronobar day                      # today's Labels, Total and Clock time
chronobar --json week              # this week, as JSON
```

`chronobar` sends one request to the running app and prints the answer. If Chronobar isn't running, it
launches it in the background first. Homebrew puts it on your `PATH`; a build from source leaves it in
`build/bin` (see [Install](install.md#build-from-source)).

A Label is the name you file time under ("Northwind, Ticket 665"), and each Label has one timer. A
Day's Total adds up every Label's time; its Clock time is how long any timer was running, counting
overlaps once, so two timers side by side for an hour make Total 2:00 and Clock time 1:00. The Panel
is the window under Chronobar's menu bar item; see [Using the app](app.md#the-parts).

The MCP server offers the same operations as tools; see [Connecting agents](connecting-agents.md).

## Starting and stopping

```sh
chronobar start "Northwind, Ticket 665"   # start a timer, or keep the one it has
chronobar status                          # the running timers and today's totals
chronobar stop "Northwind, Ticket 665"    # stop that timer
chronobar stop                            # stop the only running timer
```

Starting a Label that is already running keeps its timer going; there is never a second timer for the
same Label. Starting one Label leaves the others running, unless "Starting a timer pauses the others"
is on in Settings.

## Corrections

Recordings can be fixed after the fact:

```sh
chronobar stop Northwind --at 14:40                    # stop it back when the work finished
chronobar set-start Northwind --at 13:15               # it actually started at 13:15
chronobar add Northwind --start 9:00 --end 10:30       # a finished Entry, without a timer
chronobar add Northwind --duration 1:30 --day 2026-11-02   # or a duration on a Day
chronobar adjust Northwind 1:15 --day 2026-11-02       # set the Day's total; +15 or -10 change it
```

## Reading and tidying

```sh
chronobar day                           # today's Labels, totals and Clock time
chronobar day 2026-11-02                # another Day's
chronobar week                          # this week's daily Totals and each Label's week total
chronobar week 2026-10-28               # the week containing another Day
chronobar summary                       # today, yesterday, this week and this month
chronobar labels northwind              # suggested Labels containing "northwind"
chronobar pin "Internal meeting"        # always suggest it
chronobar archive "Northwind, Ticket 665"   # unpin it and stop suggesting it; its time stays
```

`labels` follows the ＋ form's rules: Labels with time in the last 30 days and pinned ones, minus
archived ones. With a query it also reports the status of the Label that exactly matches the query, even if it isn't suggested
(`archived`, or `unused` with no time in 30 days), or that it would be `new`. `archive` refuses a Label
Chronobar has never seen (`unknown_label`), and leaves a running timer running.

## Rules

- The words after a command are joined into one Label, so quotes are optional. For `adjust` the last
  word is the total or change. `--` ends the options: everything after it is the Label.
- `stop` and `set-start` with no Label act on the only running timer. With several running they change
  nothing and list them.
- Times are `HH:MM` today in local time, or ISO 8601 with an offset (`2026-11-02T23:15:00-05:00`).
  `--day` is `YYYY-MM-DD` and defaults to today. Options take `--at 14:40` or `--at=14:40`.
- Times in the future, an end that isn't after its start, and time a Label already has (which would
  count it twice) are refused.
- A stop, start or Entry that crosses midnight is split so each Day file holds its own time.
- Timers and Entries added from the command line are recorded as started by an agent, so idle detection leaves them
  alone.

## JSON and exit status

`--json` prints the app's JSON response instead of text:

```json
{"ok": true, "op": "status", "result": {"timers": [...], "today": {...}}}
{"ok": false, "error": {"kind": "ambiguous", "message": "...", "running": [...]}}
```

Times are ISO 8601 with a UTC offset, as stored in the Day files. Totals are whole seconds:
`total_seconds`, and `elapsed_seconds` for Clock time.

The exit status is:

| Status | Meaning |
|---|---|
| 0 | The request was carried out. |
| 1 | Chronobar refused it. The error's `kind` says why. |
| 2 | A usage error. |
| 3 | The app couldn't be reached or launched. |

Error kinds: `invalid_request`, `unknown_operation`, `invalid_label`, `unknown_label`, `invalid_date`,
`not_running`, `nothing_running`, `ambiguous`, `future_time`, `end_before_start`, `overlap`,
`invalid_duration` and `malformed_file`. Over MCP there is also `no_session_timer` (see
[Connecting agents](connecting-agents.md#which-timer-stop-the-timer-means)).

## Global options

| Option | Effect |
|---|---|
| `--json` | Print the app's JSON response instead of text. |
| `--` | End of options: everything after it is the Label. |

`chronobar help` prints the full usage.

## How it reaches the app

The command never writes your data itself. The app is the only writer, and the command talks to it over
`chronobar.sock` in the data folder, which only your user can open.
