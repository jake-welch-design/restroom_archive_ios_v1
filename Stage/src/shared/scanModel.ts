import * as THREE from "three";
import { DRACOLoader } from "three/examples/jsm/loaders/DRACOLoader.js";
import type { Crop, CropBox } from "./crop";
import { patchCropShader } from "./cropShader";

let dracoLoader: DRACOLoader | null = null;

export function getDracoLoader(): DRACOLoader {
  if (!dracoLoader) {
    dracoLoader = new DRACOLoader();
    dracoLoader.setDecoderPath("./draco/");
  }
  return dracoLoader;
}

export interface ScanShading {
  uniforms: Record<string, THREE.IUniform>;
  keepActive(): boolean;
  removalCount(): number;
  cacheKey(): string;
  clippingPlanes?(): THREE.Plane[] | undefined;
  clipIntersection?(): boolean;
}

export function toUnlitMaterial(
  src: THREE.Material,
  shading: ScanShading,
): THREE.MeshBasicMaterial {
  const pbr = src as THREE.MeshStandardMaterial;
  const flat = new THREE.MeshBasicMaterial({
    name: src.name,
    map: pbr.map ?? null,
    color: pbr.color ? pbr.color.clone() : new THREE.Color(0xffffff),
    vertexColors: pbr.vertexColors ?? false,
    transparent: src.transparent,
    opacity: src.opacity,
    alphaMap: pbr.alphaMap ?? null,
    alphaTest: src.alphaTest,
    side: src.side,
    depthWrite: src.depthWrite,
    toneMapped: false,
    clipIntersection: shading.clipIntersection?.() ?? false,
  });
  const planes = shading.clippingPlanes?.();
  if (planes) flat.clippingPlanes = planes;
  flat.onBeforeCompile = (shader) => {
    Object.assign(shader.uniforms, shading.uniforms);
    patchCropShader(shader, shading.keepActive(), shading.removalCount());
  };
  flat.customProgramCacheKey = () => shading.cacheKey();
  src.dispose();
  return flat;
}

export function applyFlatMaterials(root: THREE.Object3D, shading: ScanShading) {
  root.traverse((child) => {
    const mesh = child as THREE.Mesh;
    if (!mesh.isMesh || !mesh.material) return;
    mesh.material = Array.isArray(mesh.material)
      ? mesh.material.map((m) => toUnlitMaterial(m, shading))
      : toUnlitMaterial(mesh.material, shading);
  });
}

export function measureScanBounds(
  model: THREE.Object3D | null,
  options: { exclude?: THREE.Box3[]; precise?: boolean } = {},
): THREE.Box3 {
  const { exclude = [], precise = false } = options;
  const result = new THREE.Box3().makeEmpty();
  if (!model) return result;

  model.updateMatrixWorld(true);
  const modelInverse = new THREE.Matrix4().copy(model.matrixWorld).invert();
  const toModel = new THREE.Matrix4();
  const vertex = new THREE.Vector3();
  const meshBox = new THREE.Box3();

  model.traverse((child) => {
    const mesh = child as THREE.Mesh;
    if (!mesh.isMesh || !mesh.geometry) return;
    const position = mesh.geometry.attributes.position;
    if (!position) return;

    toModel.multiplyMatrices(modelInverse, mesh.matrixWorld);
    mesh.geometry.computeBoundingBox();
    if (!mesh.geometry.boundingBox) return;

    meshBox.copy(mesh.geometry.boundingBox).applyMatrix4(toModel);
    const near = exclude.filter((box) => meshBox.intersectsBox(box));
    if (!precise && !near.length) {
      result.union(meshBox);
      return;
    }

    for (let i = 0; i < position.count; i++) {
      vertex.fromBufferAttribute(position, i).applyMatrix4(toModel);
      if (!near.some((box) => box.containsPoint(vertex)))
        result.expandByPoint(vertex);
    }
  });

  return result;
}

export function boxFromCrop(crop: CropBox): THREE.Box3 {
  return new THREE.Box3(
    new THREE.Vector3(crop.minX, crop.minY, crop.minZ),
    new THREE.Vector3(crop.maxX, crop.maxY, crop.maxZ),
  );
}

export function isFullBounds(box: THREE.Box3, bounds: THREE.Box3): boolean {
  const epsilon = 1e-3;
  return (
    box.min.distanceTo(bounds.min) < epsilon &&
    box.max.distanceTo(bounds.max) < epsilon
  );
}

export function cropRounds(
  crop: Crop | null,
  bounds: THREE.Box3,
): { keep: THREE.Box3 | null; removals: THREE.Box3[] } {
  if (!crop) return { keep: null, removals: [] };
  const removals = (crop.removed ?? []).map(boxFromCrop);
  if (crop.mode === "remove")
    return { keep: null, removals: [...removals, boxFromCrop(crop.box)] };
  const keep = boxFromCrop(crop.box);
  return { keep: isFullBounds(keep, bounds) ? null : keep, removals };
}

function disposeMaterial(material: THREE.Material) {
  for (const key of Object.keys(material)) {
    const value = (material as unknown as Record<string, unknown>)[key];
    if (
      value &&
      typeof value === "object" &&
      (value as { isTexture?: boolean }).isTexture
    ) {
      (value as THREE.Texture).dispose();
    }
  }
  material.dispose();
}

export function disposeObject(obj: THREE.Object3D) {
  obj.traverse((child) => {
    const mesh = child as THREE.Mesh;
    if (mesh.isMesh) {
      mesh.geometry?.dispose();
      const mat = mesh.material as THREE.Material | THREE.Material[];
      if (Array.isArray(mat)) mat.forEach(disposeMaterial);
      else if (mat) disposeMaterial(mat);
    }
  });
}

