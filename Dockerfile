# Casys engineering toolchain
#
# One image carrying the full model-to-physics verification chain:
#   mcp-syson      SysML v2 models, constraints, part structure (z3 for solve)
#   mcp-build123d  parametric CAD as code (Python/OCCT)
#   mcp-calculix   FEA — Gmsh meshing + CalculiX linear static
#
# The first argument selects the server; everything after is passed through:
#   docker run -i --rm ghcr.io/casys-ai/engineering-toolchain syson
#   docker run -i --rm ghcr.io/casys-ai/engineering-toolchain build123d
#   docker run -i --rm ghcr.io/casys-ai/engineering-toolchain calculix

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
# kept separate so apt changes do not invalidate it.
RUN pip3 install --no-cache-dir --break-system-packages build123d

# Exports land on a mountable volume; /work is where callers mount their files.
ENV BUILD123D_EXPORT_DIR=/exports
RUN mkdir -p /exports /work
WORKDIR /work

# Pinned server versions — bump deliberately, never track latest.
# --minimum-dependency-age=0: @casys packages are often published and
# consumed the same day; the 24h supply-chain default would refuse them.
RUN deno cache --minimum-dependency-age=0 \
      jsr:@casys/mcp-syson@0.3.0/server \
      jsr:@casys/mcp-build123d@0.1.1/server \
      jsr:@casys/mcp-calculix@0.1.1/server

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
