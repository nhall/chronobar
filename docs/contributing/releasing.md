# Releasing

How to tag a release and update the Homebrew formula.
[Back to AGENTS.md](../../AGENTS.md)

The Homebrew formula's source of truth is [`packaging/homebrew/chronobar.rb`](../../packaging/homebrew/chronobar.rb).
[ADR 0006](../adr/0006-private-tap-git-clone-at-pinned-revision.md) records why it clones at a pinned tag and revision.
The tap is the `nhall/homebrew-tap` repository, which holds a copy at `Formula/chronobar.rb`.

1. Set the MCP server's version (`MCPServer.version` in `Sources/ChronobarCLI/MCPServer.swift`) and
   the formula's `tag` to the release's, commit, then tag that commit:
   `git tag v2.0.0 && git push origin v2.0.0`.
2. Set the formula's `revision` to the tag's commit (`git rev-parse v2.0.0^{commit}`), commit, and copy
   the file to the tap.
3. `brew update && brew upgrade chronobar`, then run the [manual test checklist](manual-checklist.md).

Both repositories are private. The formula clones the source with git, which authenticates with the
installer's own GitHub credentials (for example `gh auth setup-git`), so only people with access to
`nhall/chronobar` can install it. If the repositories go public, nothing else needs to change.
