/**
 * Gate: every file that names a server version must name the same one.
 *
 * WHY THIS EXISTS — the pinned version of each MCP server is repeated in four
 * places that nothing ties together: the import map and cache tasks in
 * `deno.json`, the warm-up in `Dockerfile`, the `exec` line in `entrypoint.sh`,
 * and the README. A bump that misses one of them produces an image that builds,
 * publishes and starts — then dies at runtime on `Specifier not found in cache`,
 * because the warmed cache and the executed specifier disagree. That happened on
 * 2026-08-10 with mcp-syson 0.6.0: `deno.json` and `Dockerfile` were bumped,
 * `entrypoint.sh` was not, and the container exited only once deployed.
 *
 * The entrypoint is the authority here: it is the specifier actually executed.
 *
 * mcp-server is excluded: the three servers lock different releases, and the
 * import map must not remap them to one version.
 */

const ROOT = new URL("..", import.meta.url).pathname;
const SPECIFIER = /@casys\/(mcp-[a-z0-9]+|constraint-solver)@(\d+\.\d+\.\d+)/g;
const FILES = ["deno.json", "Dockerfile", "entrypoint.sh", "README.md"];
const SHARED_PACKAGES = new Set([
  "mcp-syson",
  "mcp-build123d",
  "mcp-calculix",
  "constraint-solver",
]);
const IMAGE_TAG_FILES = ["README.md", "docker-compose.yml"];

/** Every distinct version each package is pinned to, per file. */
function pinsIn(text: string): Map<string, Set<string>> {
  const pins = new Map<string, Set<string>>();
  for (const [, pkg, version] of text.matchAll(SPECIFIER)) {
    if (!SHARED_PACKAGES.has(pkg)) continue;
    const versions = pins.get(pkg) ?? new Set<string>();
    versions.add(version);
    pins.set(pkg, versions);
  }
  return pins;
}

const perFile = new Map<string, Map<string, Set<string>>>();
for (const file of FILES) {
  perFile.set(file, pinsIn(await Deno.readTextFile(`${ROOT}${file}`)));
}

const packages = new Set(
  [...perFile.values()].flatMap((pins) => [...pins.keys()]),
);

const conflicts: string[] = [];
for (const pkg of [...packages].sort()) {
  const byVersion = new Map<string, string[]>();
  for (const [file, pins] of perFile) {
    for (const version of pins.get(pkg) ?? []) {
      byVersion.set(version, [...(byVersion.get(version) ?? []), file]);
    }
  }
  if (byVersion.size > 1) {
    const detail = [...byVersion.entries()]
      .map(([version, files]) => `${version} (${files.join(", ")})`)
      .join(" vs ");
    conflicts.push(`${pkg}: ${detail}`);
  }
}

const imageVersion = (await Deno.readTextFile(`${ROOT}VERSION`)).trim();
if (!/^\d+\.\d+\.\d+$/.test(imageVersion)) {
  conflicts.push(`VERSION: expected x.y.z, got ${JSON.stringify(imageVersion)}`);
} else {
  const tag = new RegExp(
    String.raw`engineering-toolchain(?::local)?:${imageVersion.replaceAll(".", "\\.")}`,
  );
  for (const file of IMAGE_TAG_FILES) {
    const text = await Deno.readTextFile(`${ROOT}${file}`);
    if (!tag.test(text)) {
      conflicts.push(
        `${file}: missing engineering-toolchain:${imageVersion} (or :local-${imageVersion})`,
      );
    }
  }
}

if (conflicts.length > 0) {
  console.error("Pinned versions disagree across files:");
  for (const conflict of conflicts) console.error(`  ${conflict}`);
  console.error(
    "\nThe entrypoint specifier is what runs; the Dockerfile warms the cache. " +
      "They must match, or the published image dies at startup.",
  );
  Deno.exit(1);
}

console.log(
  `Pinned versions agree across ${FILES.length} files for ` +
    `${[...packages].sort().join(", ")} (image ${imageVersion}).`,
);
