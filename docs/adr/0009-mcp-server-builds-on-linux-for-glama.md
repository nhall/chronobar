# The MCP server builds on Linux, only so Glama can list its tools

Glama (glama.ai) scores an MCP server's tool descriptions only after it builds the server from a
Dockerfile, starts it in a Linux container and calls `tools/list`. awesome-mcp-servers, the main list of
MCP servers, takes only servers with a Glama score. Chronobar is a macOS app, so without a Linux build
Glama can't score it and it can't be listed.

So `chronobar mcp` (the `chronobar-cli` product) builds on Linux, and the repository's `Dockerfile`
builds it with Swift 6.2 and runs `chronobar mcp`. On Linux the server answers `initialize` and
`tools/list` as on macOS; every tool call returns `app_unreachable`, saying Chronobar runs only on
macOS and how to install it. The app, Homebrew and everything users run stay macOS-only.

The differences are behind `#if canImport(Darwin)` or `#if os(macOS)`, so macOS keeps exactly the code
it had:

- `PanelHeight` imports CoreGraphics where it exists, and Foundation (which has `CGRect` on Linux)
  elsewhere.
- `DayFile` skips `renamex_np` (macOS's atomic swap) and goes straight to its existing fallback.
- `Channel` leaves out `sun_len` and `SO_NOSIGPIPE`, which Linux lacks, uses Glibc's `write`, and
  leaves out `ChannelServer`, which only the app uses.
- `chronobar`'s launch of the app reports that it runs only on macOS instead of running `open`.

## Consequences

- The Test workflow's `linux (MCP image)` job builds the Dockerfile and checks that the server lists
  its tools, so a macOS-only API in ChronobarCore, ChronobarOperations or ChronobarCLI fails a pull
  request rather than Glama's next build.
- The app target (`Chronobar`) is never built on Linux and may use any macOS API.
- Glama scores the tool titles and descriptions in `MCPTools.swift`; improving them improves the score.
- If Glama stops needing a Linux build, or stops mattering for being listed, this can be removed with the
  Dockerfile and the job.
