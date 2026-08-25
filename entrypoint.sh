#!/bin/sh
# First argument selects the stateless HTTP MCP server. The caller must pass
# both --port and --hostname; no other transport is exposed by this image.
set -e

SERVER="$1"
if [ -n "$SERVER" ]; then shift; fi

has_port=false
has_hostname=false
for argument in "$@"; do
  case "$argument" in
    --port|--port=*) has_port=true ;;
    --hostname|--hostname=*) has_hostname=true ;;
  esac
done

if [ "$has_port" != true ] || [ "$has_hostname" != true ]; then
  echo "Usage: <syson|build123d|calculix> --port=<port> --hostname=<hostname>" >&2
  exit 64
fi

case "$SERVER" in
  syson)
    exec deno run --config /opt/engineering-toolchain/deno.json --allow-all --cached-only --frozen jsr:@casys/mcp-syson@0.6.0/server "$@"
    ;;
  build123d)
    exec deno run --config /opt/engineering-toolchain/deno.json --allow-all --cached-only --frozen jsr:@casys/mcp-build123d@0.5.0/server "$@"
    ;;
  calculix)
    exec deno run --config /opt/engineering-toolchain/deno.json --allow-all --cached-only --frozen jsr:@casys/mcp-calculix@0.7.0/server "$@"
    ;;
  *)
    echo "Usage: <syson|build123d|calculix> --port=<port> --hostname=<hostname>" >&2
    exit 64
    ;;
esac
