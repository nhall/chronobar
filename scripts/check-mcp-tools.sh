#!/bin/sh
# Starts an MCP server over stdio, as a client or Glama's inspection would, and checks that it answers
# initialize and lists its tools. Prints the tool names; exits non-zero if there are none.
#
#   scripts/check-mcp-tools.sh <command that starts the server...>
#   scripts/check-mcp-tools.sh docker run -i --rm chronobar-mcp
#
# Needs jq.
set -eu

[ "$#" -gt 0 ] || { echo "usage: $0 <command...>" >&2; exit 2; }

replies=$(
    {
        printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"check-mcp-tools","version":"1"}}}'
        printf '%s\n' '{"jsonrpc":"2.0","method":"notifications/initialized"}'
        printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
        sleep 5
    } | timeout 60 "$@" || true
)

server=$(printf '%s\n' "$replies" | jq -r 'select(.id == 1) | .result.serverInfo | "\(.name) \(.version)"')
tools=$(printf '%s\n' "$replies" | jq -r 'select(.id == 2) | .result.tools[].name')

if [ -z "$server" ]; then
    echo "no initialize reply" >&2
    printf '%s\n' "$replies" >&2
    exit 1
fi
if [ -z "$tools" ]; then
    echo "$server listed no tools" >&2
    printf '%s\n' "$replies" >&2
    exit 1
fi
echo "$server: $(printf '%s\n' "$tools" | wc -l | tr -d ' ') tools"
printf '%s\n' "$tools"
