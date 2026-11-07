# The MCP server uses the official Swift SDK, pinned exactly at 0.12.1

`chronobar mcp` is built on `modelcontextprotocol/swift-sdk`, pinned with `exact: "0.12.1"` in
Package.swift, rather than a hand-written JSON-RPC loop. Spike #47 showed the whole package, app
included, builds with the Command Line Tools alone (no Xcode), that the SDK ships a
`Package@swift-6.0.swift` so our tools version stays 6.0 (the spec's "Swift 6.1 floor" was wrong), and
that it negotiates protocol 2025-11-25 with current clients.

An exact pin, not a range, because the SDK is pre-1.0 (a minor version may change its API) and the
Homebrew formula builds on the user's Mac, so what was tested must be what gets fetched.

## Consequences

- Upgrading the SDK is a deliberate change: re-check the Command Line Tools build, the tools version
  and a real client session.
- Clients that first probe `server/discover` get a -32601 and fall back to `initialize`; that one
  error in logs is expected.
- The SDK lives only in the `ChronobarCLI` target; the app and Core don't link it.
