# Releasing

How to tag a release, update the Homebrew formula and publish the release on GitHub.
[Back to AGENTS.md](../../AGENTS.md)

The Homebrew formula's source of truth is [`packaging/homebrew/chronobar.rb`](../../packaging/homebrew/chronobar.rb).
[ADR 0006](../adr/0006-private-tap-git-clone-at-release-tag.md) records why it clones at a release tag, with the tag's commit recorded beside it.
The tap is the `nhall/homebrew-tap` repository, which holds a copy at `Formula/chronobar.rb`.

1. Set the MCP server's version (`MCPServer.version` in `Sources/ChronobarCLI/MCPServer.swift`) and
   the formula's `tag` to the release's, commit, then tag that commit:
   `git tag vX.Y.Z && git push origin vX.Y.Z`.
2. Set the formula's `revision` to the tag's commit (`git rev-parse vX.Y.Z^{commit}`), commit, and copy
   the file to the tap.
3. `brew update && brew upgrade chronobar`, then run the [manual test checklist](manual-checklist.md).
4. Publish the release on GitHub, titled "Chronobar X.Y.Z", with notes for users (what's new, changed
   or fixed, and how to upgrade):
   `gh release create vX.Y.Z --verify-tag --latest --title "Chronobar X.Y.Z" --notes-file <notes>`.
   A bare tag doesn't show in the repository's Releases.
