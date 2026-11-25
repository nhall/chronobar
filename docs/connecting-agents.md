# Connecting agents

How to register Chronobar's MCP server with your agent, what to ask it, and the tools it offers.
[Back to the README](../README.md)

`chronobar mcp` is an MCP server on standard input and output, so any MCP client can launch it: register
the command `chronobar` with the argument `mcp` as a stdio server. Each setup below adds it so it's available
everywhere you use that client.

## Setup

### Claude Code

```sh
claude mcp add --scope user chronobar -- chronobar mcp
```

### Codex

```sh
codex mcp add chronobar -- chronobar mcp
```

or in `~/.codex/config.toml`:

```toml
[mcp_servers.chronobar]
command = "chronobar"
args = ["mcp"]
```

### Gemini CLI

```sh
gemini mcp add --scope user chronobar chronobar mcp
```

or in `~/.gemini/settings.json`, under `mcpServers` as in the JSON below.

### Claude Desktop and Cursor

Both read a JSON file. In Claude Desktop, Settings › Developer › Edit Config opens
`~/Library/Application Support/Claude/claude_desktop_config.json`. For Cursor, edit
`~/.cursor/mcp.json`. Add `chronobar` to `mcpServers`:

```json
{
  "mcpServers": {
    "chronobar": {
      "command": "/opt/homebrew/bin/chronobar",
      "args": ["mcp"]
    }
  }
}
```

Apps opened from the Dock or Finder don't get your shell's `PATH`, so give the full path: `brew --prefix`
followed by `/bin/chronobar` (`/usr/local/bin/chronobar` on an Intel Mac). Then quit and reopen the
app. The full path works in the other clients too, if one can't find `chronobar`.

## Things to ask

- "Start a timer for Northwind, Ticket 665."
- "Stop it back when you finished."
- "I actually started at 1:15."
- "Add a line item for the hour that took us."
- "How much time went to Northwind this week?"

Each timer belongs to a Label, the name you file time under, and an agent addresses timers by Label.
Timers an agent starts are marked in the Panel (the window under Chronobar's menu bar item, the Pill)
with a small terminal icon ("Started by an agent; not
paused for idle time"), and the Day file records them with `"source": "agent"`.

## Tools

The server offers a tool for each [command](command-line.md), with the same rules, except which timer a bare `stop` or `set_start` means (see below):

| Tool | Does |
|---|---|
| `status` | Lists the running timers and today's totals. |
| `start` | Starts a timer for a Label, or keeps the one it has. |
| `stop` | Stops a timer, now or back at a given time. |
| `set_start` | Moves a running timer's start. |
| `add_entry` | Adds a finished line item, by start and end or by duration on a Day. |
| `adjust` | Sets or changes a Label's total on a Day. |
| `relabel` | Moves all of a Label's time on a Day to another Label. |
| `day` | Reads a Day's rows, Total and Clock time. |
| `week` | Reads a week's daily Totals and each Label's week total. |
| `summary` | Reads today, yesterday, this week and this month. |
| `labels` | Finds suggested Labels matching what you said. |
| `archive` | Unpins a Label and hides it from suggestions; its time stays. |
| `pin` | Keeps a Label in the suggestions. |

Each tool returns the stored times and totals as structured JSON, so the agent can tell you exactly what
was recorded, and declares that JSON's shape as an output schema. A refusal is a tool error: its message,
then the whole error as JSON in text (`kind`, `message` and, where it helps, the running timers).
Times are ISO 8601 with an offset; `elapsed_seconds` is the Clock time: how long any timer was
running, counting overlaps once. Each Day's totals, and `day`'s rows and `week`'s totals and Labels,
also give `total_minutes` (and for totals `elapsed_minutes`), the hours and minutes the Panel shows,
which add up to the Total under them. Agents are told to quote those
to you and to do arithmetic with the seconds, so the figures they give you match the Panel.

## Which timer "stop the timer" means

Each session runs its own server, which remembers the Labels that session started (a `start` that found
the Label already running doesn't count). `stop` and `set_start` with no Label act on that session's
timer, whatever else is running. If it started several that are still running, or none, they change
nothing and list the running timers (`ambiguous` or `no_session_timer`), so the agent asks which.

A timer the session started and then relabeled with `relabel` stays the session's under its new Label.
One relabeled elsewhere (in the Panel, from the command line or by another session) no longer is.

Any session can stop any timer by name. Closing a session leaves its timers running; the long-running
warning catches one that's forgotten.

## Away from the keyboard

Idle detection applies only to timers started in the app, and quitting Chronobar leaves agents' timers
running. See [Using the app](app.md#idle-quitting-and-long-running-timers).
