# Casys engineering toolchain

One Docker image carrying the full **model-to-physics verification chain** — zero native installs:

| Server | What it does | System deps bundled |
|---|---|---|
| [`mcp-syson`](https://github.com/Casys-AI/mcp-syson) | SysML v2 models, constraints, part structure | z3 (constraint solving) |
| [`mcp-build123d`](https://github.com/Casys-AI/mcp-build123d) | parametric CAD as code, exact mass properties, STEP/STL/GLTF | Python + build123d/OCCT |
| [`mcp-calculix`](https://github.com/Casys-AI/mcp-calculix) | FEA — meshing + linear static solve | Gmsh + CalculiX |

The first argument selects the server; anything after is passed through.

```bash
docker run -i --rm ghcr.io/casys-ai/engineering-toolchain syson
docker run -i --rm ghcr.io/casys-ai/engineering-toolchain build123d
docker run -i --rm ghcr.io/casys-ai/engineering-toolchain calculix
```

## The whole chain in one command

```bash
docker compose up -d
```

brings up SysON (the SysML v2 modeler, http://localhost:8180) plus the three MCP servers over HTTP (ports 3009 / 3014 / 3015, loopback only). `mcp-build123d` and `mcp-calculix` share the `exports` volume, so a STEP exported by `build123d_export` is immediately readable by `calculix_solve_static` at `/exports/<name>.step`.

## stdio mode (Claude Desktop / PML)

```json
{
  "mcpServers": {
    "syson": {
      "command": "docker",
      "args": ["run", "-i", "--rm",
               "--add-host=host.docker.internal:host-gateway",
               "-e", "SYSON_URL=http://host.docker.internal:8180",
               "ghcr.io/casys-ai/engineering-toolchain", "syson"]
    },
    "build123d": {
      "command": "docker",
      "args": ["run", "-i", "--rm",
               "-v", "cad-exports:/exports",
               "ghcr.io/casys-ai/engineering-toolchain", "build123d"]
    },
    "calculix": {
      "command": "docker",
      "args": ["run", "-i", "--rm",
               "-v", "cad-exports:/exports",
               "ghcr.io/casys-ai/engineering-toolchain", "calculix"]
    }
  }
}
```

Notes that matter:

- **SYSON_URL** — `host.docker.internal` reaches a SysON running on the host (the `--add-host` flag makes it work on Linux too). If SysON runs in the compose stack instead, use HTTP mode or join the compose network.
- **Shared volume** — the same named volume (`cad-exports`) mounted in build123d and calculix is what lets a STEP flow between them; pass `/exports/<name>.step` as `step_path`.
- **HTTP inside a container** — the servers bind loopback by default (they execute code; that default is deliberate). Inside a container you must pass `--hostname=0.0.0.0` to be reachable through the port mapping — the compose file does exactly that, while publishing the ports loopback-only on the host.

## Version pinning

The image pins exact server versions — currently `mcp-syson@0.3.1`, `mcp-build123d@0.1.2`, `mcp-calculix@0.1.1`. Bumping them is a deliberate one-line Dockerfile change, never a `latest` drift. The base is Ubuntu 24.04 (Debian trixie dropped `calculix-ccx`), with the Deno binary copied from the official image.

## Security model

`build123d` executes arbitrary Python and `calculix` runs solvers on caller-named files — inside the container, which contains them but is not a strong sandbox (mounted volumes are writable, the network is reachable unless restricted). The trust model is unchanged from running the servers natively: only expose them to callers you trust. Add `--network=none` to the build123d/calculix `docker run` lines if the scripts you run need no network at all — the tools themselves never do.

## Build locally

```bash
docker build -t engineering-toolchain .
docker run --rm engineering-toolchain calculix --help 2>&1 | head -2   # usage line
```

## License

MIT
