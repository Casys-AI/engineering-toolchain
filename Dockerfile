# Casys engineering toolchain
#
# One image carrying the full model-to-physics verification chain:
#   mcp-syson      SysML v2 models, constraints, part structure (z3 for solve)
#   mcp-build123d  parametric CAD as code (Python/OCCT)
#   mcp-calculix   FEA — Gmsh meshing + CalculiX linear static
#
# The first argument selects the stateless HTTP server. The caller supplies
# its explicit port and hostname, for example: syson --port=3009 --hostname=0.0.0.0

# Ubuntu base rather than the Deno image's Debian trixie: calculix-ccx was
# dropped from trixie, while Ubuntu 24.04 carries ccx 2.21, gmsh 4.12 and z3.
# Deno itself is copied in as a static binary from the official image.
FROM ubuntu:24.04

COPY --from=denoland/deno:bin-2.9.4 /deno /usr/local/bin/deno

# System backends: z3 (constraint solving), gmsh + ccx (FEA), python (CAD)
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      python3 \
      python3-pip \
      gmsh \
      calculix-ccx \
      z3 \
    && rm -rf /var/lib/apt/lists/*

# build123d pulls the OCP/OCCT wheel (~150 MB) — the heavyweight layer,
# kept separate so apt changes do not invalidate it. Pin its public API release
# just like the MCP wrapper so the primary geometry runtime cannot drift.
RUN pip3 install --no-cache-dir --break-system-packages build123d==0.11.1

# Exports land on a mountable volume; /work is where callers mount their files.
ENV BUILD123D_EXPORT_DIR=/exports
RUN mkdir -p /exports /work
WORKDIR /work

# Pinned server versions, Deno lock and dependency-age policy are versioned
# together. The only quarantine exclusions are the exact direct Casys pins and
# their locked @casys/mcp-server / @casys/constraint-solver dependencies.
WORKDIR /opt/engineering-toolchain
COPY deno.json deno.lock ./
RUN deno cache --frozen \
      jsr:@casys/mcp-syson@0.6.0/server \
      jsr:@casys/mcp-build123d@0.4.1/server \
      jsr:@casys/mcp-calculix@0.4.0/server \
      jsr:@casys/mcp-build123d@0.4.1

# Exercise the published package as it will run in the container. This catches
# non-TypeScript package assets that are missing from Deno's module graph.
RUN deno eval --cached-only --frozen \
      'import { runCadScript } from "jsr:@casys/mcp-build123d@0.4.1"; const result = await runCadScript("from build123d import Box\nresult = Box(1, 1, 1)"); if (Math.abs(result.metrics.volume_mm3 - 1) > 1e-9) throw new Error("build123d package smoke test failed");'

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
WORKDIR /work
ENTRYPOINT ["/entrypoint.sh"]
