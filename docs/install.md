# Install

How to install Chronobar with Homebrew or from source, and what to do on first run.
[Back to the README](../README.md)

## Requirements

- macOS 15.2 Sequoia or later.
- The Command Line Tools 16.3 or later (`xcode-select --install`), for Swift 6.1 or later. Xcode is not
  required. Homebrew builds Chronobar on your Mac, and Swift 6.1 needs macOS 15.2.

## Homebrew

Homebrew builds Chronobar on your Mac:

```sh
brew install nhall/tap/chronobar
```

This installs the app and the `chronobar` command, which Homebrew puts on your `PATH`. The command
launches the app installed beside it when it isn't running, so it works before you've opened the app
and after each upgrade.

Homebrew installs the app into its own prefix, not `/Applications`. To open Chronobar from Spotlight,
Launchpad and Finder, link it into `~/Applications`, then open it:

```sh
ln -sfn "$(brew --prefix)/opt/chronobar/Chronobar.app" ~/Applications/Chronobar.app
open ~/Applications/Chronobar.app
```

The link points at Homebrew's `opt` path, which always leads to the installed version, so you only
need to make it once.

Because the app is compiled on your own Mac and signed there (ad hoc), it isn't quarantined and opens
without a Gatekeeper warning. You don't need an Apple Developer account.

## First run

Click the Pill, the `0 0:00` in the menu bar: it shows how many timers are running and today's Total.
The Panel opens under it. Click ＋, type a Label (the name you file the time under, such as
"Northwind, Ticket 665") and press Return: its timer starts and the Pill counts it. Each row's ⏸ pauses that timer, and ▶ starts it again. Turn on
Start at login in Settings (⚙) if you want Chronobar in the menu bar every day.

To let your agents drive it, see [Connecting agents](connecting-agents.md).

## Update and uninstall

Update with `brew upgrade chronobar`, then quit Chronobar and open it again, so the app and the
`chronobar` command are the same version. To remove it, quit Chronobar, then:

```sh
brew uninstall chronobar
rm ~/Applications/Chronobar.app    # if you linked it
```

Your data in `~/Library/Application Support/Chronobar` is left alone; delete that folder too if you
want it gone.

## Build from source

```sh
git clone https://github.com/nhall/chronobar.git
cd chronobar
scripts/bundle-app.sh            # builds build/Chronobar.app and build/bin/chronobar
open build/Chronobar.app
```

Put `build/bin` on your `PATH`, or call `build/bin/chronobar` directly. This builds the same app and
command that Homebrew installs.
