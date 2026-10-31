export const CROP_UNIFORMS = {
  toLocal: "cropToLocal",
  keepMin: "cropKeepMin",
  keepMax: "cropKeepMax",
  removeMin: "cropRemoveMin",
  removeMax: "cropRemoveMax",
} as const;

export const CROP_VERTEX_PARS = "varying vec3 vCropWorld;";
export const CROP_VERTEX_MAIN =
  "vCropWorld = (modelMatrix * vec4(transformed, 1.0)).xyz;";

export function cropFragmentPars(keep: boolean, removals: number): string {
  const u = CROP_UNIFORMS;
  return [
    "varying vec3 vCropWorld;",
    `uniform mat4 ${u.toLocal};`,
    keep ? `uniform vec3 ${u.keepMin};\nuniform vec3 ${u.keepMax};` : "",
    removals > 0
      ? `uniform vec3 ${u.removeMin}[${removals}];\nuniform vec3 ${u.removeMax}[${removals}];`
      : "",
  ].join("\n");
}

export function cropFragmentMain(keep: boolean, removals: number): string {
  const u = CROP_UNIFORMS;
  return [
    "{",
    `  vec3 cropP = (${u.toLocal} * vec4(vCropWorld, 1.0)).xyz;`,
    keep
      ? `  if (any(lessThan(cropP, ${u.keepMin})) || any(greaterThan(cropP, ${u.keepMax}))) discard;`
      : "",
    removals > 0
      ? [
          `  for (int i = 0; i < ${removals}; i++) {`,
          `    if (all(greaterThan(cropP, ${u.removeMin}[i])) && all(lessThan(cropP, ${u.removeMax}[i]))) discard;`,
          "  }",
        ].join("\n")
      : "",
    "}",
  ].join("\n");
}

export function patchCropShader(
  shader: { vertexShader: string; fragmentShader: string },
  keep: boolean,
  removals: number,
): void {
  if (!keep && removals === 0) return;
  shader.vertexShader = shader.vertexShader
    .replace("#include <common>", `#include <common>\n${CROP_VERTEX_PARS}`)
    .replace(
      "#include <project_vertex>",
      `#include <project_vertex>\n${CROP_VERTEX_MAIN}`,
    );
  shader.fragmentShader = shader.fragmentShader
    .replace(
      "#include <common>",
      `#include <common>\n${cropFragmentPars(keep, removals)}`,
    )
    .replace(
      "#include <clipping_planes_fragment>",
      `${cropFragmentMain(keep, removals)}\n#include <clipping_planes_fragment>`,
    );
}

