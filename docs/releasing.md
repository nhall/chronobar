# Releasing

The Homebrew formula's source of truth is [`packaging/homebrew/chronobar.rb`](../packaging/homebrew/chronobar.rb).
The tap is the `nhall/homebrew-tap` repository, which holds a copy at `Formula/chronobar.rb`.

1. Set the MCP server's version (`MCPServer.version` in `Sources/ChronobarCLI/MCPServer.swift`) to the
   release's, then tag it: `git tag v2.0.0 && git push origin v2.0.0`.
2. Hash the tarball:
   `curl -L https://github.com/nhall/chronobar/archive/refs/tags/v2.0.0.tar.gz | shasum -a 256`.
3. Update `url` and `sha256` in `packaging/homebrew/chronobar.rb`, commit, and copy the file to the tap.
4. `brew update && brew upgrade chronobar`, then run the [manual test checklist](manual-checklist.md).

The formula needs the repository to be public: Homebrew downloads the tarball without credentials.
