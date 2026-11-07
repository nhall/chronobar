# The command line and MCP server reach the app over a Unix socket

`chronobar` (both its subcommands and `chronobar mcp`) never reads or writes the data folder itself.
It sends newline-delimited JSON requests to the running app over `chronobar.sock` in the data folder,
created owner-only (0600, under a umask so it is never briefly wider), and the app answers through the
same Operations layer for both front ends. If the socket doesn't answer, `chronobar` launches the app
and waits for it.

This keeps the app the only writer (ADR 0002): a CLI that wrote Day files itself would race the app
and leave the running Timers, the Pill and the Panel out of step with the files. One set of
validation rules then covers the app, scripts and agents. A socket file, unlike a localhost port, is
limited to the user by its permissions alone.

## Consequences

- Owner-only file permissions are the only authentication, by design (the spec ruled anything more
  out of scope).
- Requests are run on the main thread's run loop in common modes, so they are still answered while
  the app shows a modal alert (such as the idle alert).
- A refused connection is treated as "not running", so a stale `chronobar.sock` left after a quit or
  crash is harmless.
