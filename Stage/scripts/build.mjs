import { build } from "esbuild";
import { cp, mkdir, rm } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const outDir = resolve(root, "../RestroomArchive/Resources/StageDist");

await rm(outDir, { recursive: true, force: true });
await mkdir(resolve(outDir, "draco"), { recursive: true });

await build({
  entryPoints: [resolve(root, "src/main.ts")],
  outfile: resolve(outDir, "stage.js"),
  bundle: true,
  format: "esm",
  target: ["safari17", "ios17"],
  minify: true,
  sourcemap: false,
});

await cp(resolve(root, "index.html"), resolve(outDir, "index.html"));
const dracoSrc = resolve(
  root,
  "node_modules/three/examples/jsm/libs/draco/gltf",
);
for (const file of [
  "draco_decoder.wasm",
  "draco_wasm_wrapper.js",
  "draco_decoder.js",
]) {
  await cp(resolve(dracoSrc, file), resolve(outDir, "draco", file));
}

console.log("Built StageDist ->", outDir);
