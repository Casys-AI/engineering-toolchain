# Casys engineering toolchain

One Docker image carrying the full **model-to-physics verification chain** — zero native installs:

| Server | What it does | System deps bundled |
|---|---|---|
| [`mcp-syson`](https://github.com/Casys-AI/mcp-syson) | SysML v2 models, constraints, part structure | z3 (constraint solving) |
| [`mcp-build123d`](https://github.com/Casys-AI/mcp-build123d) | parametric CAD as code, exact mass properties, STEP/STL/GLTF | Python + build123d/OCCT |
| [`mcp-calculix`](https://github.com/Casys-AI/mcp-calculix) | FEA — meshing + linear static solve | Gmsh + CalculiX |

The first argument selects a **stateless HTTP** server. Callers must pass its
port and hostname explicitly; the image exposes HTTP only.

```bash
docker run --rm -p 127.0.0.1:3009:3009 ghcr.io/casys-ai/engineering-toolchain:0.2.0 \
  syson --port=3009 --hostname=0.0.0.0
docker run --rm -p 127.0.0.1:3014:3014 ghcr.io/casys-ai/engineering-toolchain:0.2.0 \
  build123d --port=3014 --hostname=0.0.0.0
docker run --rm -p 127.0.0.1:3015:3015 ghcr.io/casys-ai/engineering-toolchain:0.2.0 \
  calculix --port=3015 --hostname=0.0.0.0
```

## The whole chain in one command

```bash
docker compose up -d
```

brings up SysON (the SysML v2 modeler, http://localhost:8180) plus the three MCP servers over stateless HTTP (ports 3009 / 3014 / 3015, loopback only). Every MCP endpoint is `/mcp`, emits complete responses without an MCP session, and publishes its registered viewer resources through `resources/list`. `mcp-build123d` and `mcp-calculix` share the `exports` volume, so a STEP exported by `build123d_export` is immediately readable by `calculix_solve_static` at `/exports/<name>.step`.

Notes that matter:

- **SYSON_URL** — the Compose service uses `http://syson-app:8080`; an alternate deployment must point this variable at its SysON instance.
- **Shared volume** — the same named volume (`exports`) mounted in build123d and calculix is what lets a STEP flow between them; pass `/exports/<name>.step` as `step_path`.
- **HTTP inside a container** — the servers bind loopback by default. Compose passes `--hostname=0.0.0.0` so its loopback-only host mappings can reach them.

## Version pinning

The image pins exact server versions — `mcp-syson@0.4.0`, `mcp-build123d@0.2.0`, and `mcp-calculix@0.2.0`. `deno.json` keeps a P1D dependency-age quarantine. Deno scopes an age exclusion by package name rather than package version, so the exclusions are limited to five audited Casys names; their `imports`, Docker specifiers and frozen `deno.lock` bind them to `mcp-syson@0.4.0`, `mcp-build123d@0.2.0`, `mcp-calculix@0.2.0`, `mcp-server@0.24.0`, and `constraint-solver@0.1.0`. The runtime is cached-only. The base is Ubuntu 24.04 (Debian trixie dropped `calculix-ccx`), with the Deno binary copied from the official image.

## Security model

`build123d` executes arbitrary Python and `calculix` runs solvers on caller-named files — inside the container, which contains them but is not a strong sandbox (mounted volumes are writable, the network is reachable unless restricted). The trust model is unchanged from running the servers natively: only expose them to callers you trust. Add `--network=none` to build123d/calculix deployments if their scripts need no network — the tools themselves never do.

## Build locally

```bash
docker build -t engineering-toolchain:local-0.2.0 .
docker run --rm engineering-toolchain:local-0.2.0 calculix --port=3015 --hostname=0.0.0.0
```

## License

MIT
