# Development

## Building from source

You need macOS 14 Sonoma or later and the Command Line Tools 16 or later (`xcode-select --install`), for
Swift 6.0 or later. Xcode is not required to build.

```sh
git clone https://github.com/nhall/chronobar.git
cd chronobar
scripts/bundle-app.sh            # builds build/Chronobar.app and build/bin/chronobar
open build/Chronobar.app
```

Put `build/bin` on your `PATH`, or call `build/bin/chronobar` directly. Without `--dev`, the script
builds exactly what the Homebrew formula installs.

`swift test` runs the tests. The test suite needs Xcode, because Swift Testing isn't usable with the
Command Line Tools alone; building the app doesn't.

## A development copy

To try a change without touching the Chronobar you use every day, build a development copy:

```sh
scripts/bundle-app.sh --dev      # builds "build/Chronobar Dev.app"
open "build/Chronobar Dev.app"
```

It runs next to the everyday copy and shares nothing with it:

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

## Checking a release

The timing logic is covered by `swift test`; the menu bar, Panel and system behaviour are checked by
hand with the [manual test checklist](manual-checklist.md). [Releasing](releasing.md) covers tagging
and the Homebrew formula.
