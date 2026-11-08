# Development

Running the tests, and a development copy that runs beside your everyday Chronobar.
[Back to AGENTS.md](../../AGENTS.md)

## Building and testing

[Install](../install.md#build-from-source) shows how to build from source. Without `--dev`,
`scripts/bundle-app.sh` builds exactly what the Homebrew formula installs.

`swift test` runs the tests. The test suite needs Xcode, because Swift Testing isn't usable with the
Command Line Tools alone; building the app doesn't.

## A development copy

To try a change without touching the Chronobar you use every day, build a development copy:

```sh
scripts/bundle-app.sh --dev      # builds "build/Chronobar Dev.app"
open "build/Chronobar Dev.app"
```

It runs next to the everyday copy and shares no settings or data with it:

| | Everyday copy | Development copy |
|---|---|---|
| App | `Chronobar.app` | `Chronobar Dev.app` |
| Bundle ID (settings, start at login) | `io.github.nhall.chronobar` | `io.github.nhall.chronobar.dev` |
| Data folder | `~/Library/Application Support/Chronobar` | `~/Library/Application Support/Chronobar Dev` |
| Process (for `killall`) | `Chronobar` | `ChronobarDev` |
| Command line | `chronobar …` | `chronobar --dev …` |
| MCP server | `chronobar mcp` | `chronobar --dev mcp` |

Its Pill ends in an orange **DEV** mark, its Dock icon carries a **DEV** badge, and its ⚙ menu reads
**Quit Chronobar Dev**, so with both running you can tell which Pill to click. The everyday copy's Pill
has no mark.

To start the development copy fresh, quit it, then delete its data folder and run
`defaults delete io.github.nhall.chronobar.dev`.

### Command line and agents

`--dev`, before the command, makes `chronobar` talk to the development copy instead of the everyday
one (`chronobar --dev status`). `chronobar --dev mcp` is the development copy's MCP server; register it
under a name of its own, for example in Claude Code:

```sh
claude mcp add chronobar-dev -- <path>/build/bin/chronobar --dev mcp
```

## Checking a release

See the [manual test checklist](manual-checklist.md). [Releasing](releasing.md) covers tagging and the
Homebrew formula.
