# Chronobar

A menu bar time tracker for macOS that times several pieces of work at once, and that your AI agents
can start, stop and correct for you.

<p>
  <img src="docs/images/panel.png" alt="The Chronobar Pill in the menu bar, 3 timers running and 6:39 today, with the Panel open below it: Saturday's Week strip, Total 6:39 · Clock time 2:59, and four Labels, three of them running and two marked as started by an agent" width="346" height="350">
</p>

## Why

If you run an agent session for each client, an hour spent moving between them is one hour of your
time and an hour of work on each client's job. A tracker with one timer can't record that. Chronobar
gives each piece of work its own timer, running side by side, and your agents start and stop them
through MCP or a plain command line. Everything stays on your Mac.

## Features

- Timers run side by side, one per Label you type, such as "Northwind, Ticket 665".
- Agents drive it through MCP or the `chronobar` command, and "stop the timer" stops the session's own.
- Fix a recording after the fact: stop it back at 14:40, move a start, add a line item, set a total.
- The Panel shows the Total you'll bill beside the Clock time you actually worked.
- Idle checks cover the timers you started; agents' timers keep going, and any that runs too long raises a warning.
- Your data is plain text you can read and edit, and the app works fully with the keyboard and VoiceOver.

## Quick start

You need macOS 14 or later and the Command Line Tools (`xcode-select --install`).

```sh
brew install nhall/tap/chronobar
claude mcp add --scope user chronobar -- chronobar mcp
```

The second line connects Claude Code. For Claude Desktop, Codex, Cursor and Gemini CLI, see
[Connecting agents](docs/connecting-agents.md). Then ask your agent to "start a timer for Northwind,
Ticket 665": Chronobar opens in the menu bar and the timer starts.

## Documentation

| Page | What it covers |
|---|---|
| [Install](docs/install.md) | Requirements, Homebrew, first run, updating, uninstalling and building from source. |
| [Using the app](docs/app.md) | The Pill, the Panel, its keys, idle handling and Settings. |
| [Connecting agents](docs/connecting-agents.md) | Setup for each MCP client, things to ask, and the tools. |
| [The command line](docs/command-line.md) | Every command, its rules, JSON output and exit status. |
| [Data format](docs/data-format.md) | Where your data lives, the Day files, Label lists and how totals add up. |
| [Development](docs/development.md) | Tests and a development copy beside your everyday one. |
| [Manual test checklist](docs/manual-checklist.md) | The hand checks to run before a release. |
| [Releasing](docs/releasing.md) | Tagging a release and updating the Homebrew formula. |

## License

MIT. See [LICENSE](LICENSE).
