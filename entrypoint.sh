#!/bin/sh
# First argument selects the MCP server, the rest is passed through.
set -e

SERVER="$1"
if [ -n "$SERVER" ]; then shift; fi

case "$SERVER" in
  syson)
    exec deno run --allow-all --minimum-dependency-age=0 jsr:@casys/mcp-syson@0.3.1/server "$@"
    ;;
  build123d)
    exec deno run --allow-all --minimum-dependency-age=0 jsr:@casys/mcp-build123d@0.1.2/server "$@"
    ;;
  calculix)
    exec deno run --allow-all --minimum-dependency-age=0 jsr:@casys/mcp-calculix@0.1.1/server "$@"
    ;;
  *)
    echo "Usage: <syson|build123d|calculix> [server args]" >&2
    echo "  e.g.: syson --http --port=3009 --hostname=0.0.0.0" >&2
    exit 64
    ;;
esac
