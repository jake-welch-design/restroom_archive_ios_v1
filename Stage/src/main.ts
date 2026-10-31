import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import {
  postStageEvent,
  type CameraMode,
  type CameraSnapshot,
  type CropResult,
  type StageAnnotation,
  type StageCommand,
} from "./bridge";
import {
  MAX_CROP_REMOVALS,
  type Crop,
  type CropBox,
  type CropMode,
} from "./shared/crop";
import {
  clampInsideEdges,
  createCropGizmo,
  type CropGizmo,
  type CropGizmoTool,
  type RotateAxis,
} from "./shared/cropGizmo";
import { isLevelled, type Level } from "./shared/levelling";
import {
  applyFlatMaterials as applySharedFlatMaterials,
  boxFromCrop,
  cropRounds,
  disposeObject,
  getDracoLoader,
  isFullBounds as isWithinBounds,
  measureScanBounds as measureBounds,
  type ScanShading,
} from "./shared/scanModel";

const canvas = document.getElementById("stage-canvas") as HTMLCanvasElement;
const markersLayer = document.getElementById("markers-layer") as HTMLDivElement;

let mode: CameraMode = "orbit";
let createMode = false;
let markersVisible = true;
let cropEditing = false;
let cropReady = false;
let cropTool: CropGizmoTool = "box";
let cropMode: CropMode = "keep";
let cropDraft: CropBox | null = null;
let cropEmptiesScan = false;
let cropConfirmed: { keep: CropBox | null; removals: CropBox[] } = {
  keep: null,
  removals: [],
};
let removalPending = false;
let rotateDegrees: number | null = null;

let currentSlug: string | null = null;
let annotations: StageAnnotation[] = [];
let selectedAnnotationId: number | null = null;
const markerElements = new Map<number, HTMLButtonElement>();

let renderer: THREE.WebGLRenderer | null = null;
let scene: THREE.Scene | null = null;
let camera: THREE.PerspectiveCamera | null = null;
let controls: OrbitControls | null = null;
let currentModel: THREE.Group | null = null;
let levelNode: THREE.Group | null = null;
let gizmo: CropGizmo | null = null;

let userInteracted = false;
let orbitDistance = 4;
let loadId = 0;

const originalBounds = new THREE.Box3();
const appliedBox = new THREE.Box3();
const appliedCentre = new THREE.Vector3();
const Y_AXIS = new THREE.Vector3(0, 1, 0);
const clipBox = new THREE.Box3();
let clipMode: CropMode = "keep";
let clippingActive = false;
let committedCrop: Crop | null = null;

let viewBeforeCrop: {
  mode: CameraMode;
  fov: number;
  position: THREE.Vector3;
  target: THREE.Vector3;
  rotationX: number;
  rotationY: number;
} | null = null;

const draftKeep = new THREE.Box3();
let draftRemovals: THREE.Box3[] = [];
let settingBox = false;

const roundOutlines = new THREE.Group();
roundOutlines.matrixAutoUpdate = false;

const shaderKeep = new THREE.Box3();
let shaderKeepActive = false;
let shaderRemovals: THREE.Box3[] = [];
let shaderCropKey = "0:0";
const cropUniforms = {
  cropToLocal: { value: new THREE.Matrix4() },
  cropKeepMin: { value: shaderKeep.min },
  cropKeepMax: { value: shaderKeep.max },
  cropRemoveMin: { value: [] as THREE.Vector3[] },
  cropRemoveMax: { value: [] as THREE.Vector3[] },
};

const CROP_FRAME_MARGIN = 1.08;
const DEFAULT_POV_RISE = 0.2;

let draftPovY: number | null = null;
let draftPovXZ: { x: number; z: number } | null = null;

const draftRotation = new THREE.Quaternion();
const draftPivot = new THREE.Vector3();
const rotationAtDragStart = new THREE.Quaternion();
const rotationAtToolStart = new THREE.Quaternion();
const committedRotation = new THREE.Quaternion();
const relativeRotation = new THREE.Quaternion();
const IDENTITY = new THREE.Quaternion();
const ROTATION_EPSILON = (0.01 * Math.PI) / 180;
const AXES: Record<RotateAxis, THREE.Vector3> = {
  x: new THREE.Vector3(1, 0, 0),
  y: new THREE.Vector3(0, 1, 0),
  z: new THREE.Vector3(0, 0, 1),
};

let cropStartToken = 0;
const draftFrame = new THREE.Box3();
const cropLocalPlanes = Array.from({ length: 6 }, () => new THREE.Plane());
const cropWorldPlanes = Array.from({ length: 6 }, () => new THREE.Plane());

let modelRadius = 2;
let lastProbeAt = 0;
const probeRaycaster = new THREE.Raycaster();
const probeDir = new THREE.Vector3();
const PROBE_INTERVAL_MS = 250;
const PROBE_RATIO = 2.5;

let tweenRaf = 0;
let tweenActive = false;

const povState = {
  rotationX: 0,
  rotationY: 0,
  dragging: false,
  lastX: 0,
  lastY: 0,
  fov: 80,
};

let pointerDownX = 0;
let pointerDownY = 0;
const activePointers = new Map<number, { x: number; y: number }>();
let pinchStartDist = 0;
let pinchStartFov = 0;

function getPinchDist(): number {
  const pts = [...activePointers.values()];
  const dx = pts[0].x - pts[1].x;
  const dy = pts[0].y - pts[1].y;
  return Math.sqrt(dx * dx + dy * dy);
}

function povPosition(
  out = new THREE.Vector3(),
  theta = currentModel?.rotation.y ?? 0,
): THREE.Vector3 {
  const { povX, povY, povZ } = committedCrop ?? {};
  out.set(0, povY == null ? DEFAULT_POV_RISE : povY - appliedCentre.y, 0);
  if (povX != null && povZ != null) {
    out.x = povX - appliedCentre.x;
    out.z = povZ - appliedCentre.z;
  }
  return out.applyAxisAngle(Y_AXIS, theta);
}

function applyPovRotation() {
  if (!camera) return;
  povState.rotationX = Math.max(
    -Math.PI / 2,
    Math.min(Math.PI / 2, povState.rotationX),
  );
  camera.rotation.set(povState.rotationX, povState.rotationY, 0, "YXZ");
}

const shading: ScanShading = {
  uniforms: cropUniforms,
  keepActive: () => shaderKeepActive,
  removalCount: () => shaderRemovals.length,
  cacheKey: () => shaderCropKey,
  clippingPlanes: () => (clippingActive ? cropWorldPlanes : undefined),
  clipIntersection: () => clipMode === "remove",
};

function cropFromBox(box: THREE.Box3): CropBox {
  return {
    minX: box.min.x,
    minY: box.min.y,
    minZ: box.min.z,
    maxX: box.max.x,
    maxY: box.max.y,
    maxZ: box.max.z,
  };
}

function wouldEmptyScan(box: THREE.Box3): boolean {
  return cropMode === "remove" && removalPending && box.containsBox(draftKeep);
}

function sameBox(a: THREE.Box3, b: THREE.Box3): boolean {
  const epsilon = 1e-4;
  return (
    a.min.distanceTo(b.min) <= epsilon && a.max.distanceTo(b.max) <= epsilon
  );
}

function applyLevel(rotation: THREE.Quaternion, pivot: THREE.Vector3) {
  if (!levelNode) return;
  levelNode.quaternion.copy(rotation);
  levelNode.position.copy(pivot).sub(pivot.clone().applyQuaternion(rotation));
}

function draftLevel(): Level | null {
  const level: Level = {
    rotation: {
      x: draftRotation.x,
      y: draftRotation.y,
      z: draftRotation.z,
      w: draftRotation.w,
    },
    pivot: { x: draftPivot.x, y: draftPivot.y, z: draftPivot.z },
  };
  return isLevelled(level) ? level : null;
}

function rotationOf(crop: Crop | null): THREE.Quaternion {
  const r = crop?.level?.rotation;
  return r ? new THREE.Quaternion(r.x, r.y, r.z, r.w) : new THREE.Quaternion();
}

function rawCentre(): THREE.Vector3 {
  const bounds = new THREE.Box3().makeEmpty();
  if (!levelNode) return bounds.getCenter(new THREE.Vector3());
  levelNode.updateMatrixWorld(true);
  const inverse = levelNode.matrixWorld.clone().invert();
  const toLevel = new THREE.Matrix4();
  const meshBox = new THREE.Box3();
  levelNode.traverse((child) => {
    const mesh = child as THREE.Mesh;
    if (!mesh.isMesh || !mesh.geometry) return;
    mesh.geometry.computeBoundingBox();
    if (!mesh.geometry.boundingBox) return;
    toLevel.multiplyMatrices(inverse, mesh.matrixWorld);
    bounds.union(meshBox.copy(mesh.geometry.boundingBox).applyMatrix4(toLevel));
  });
  return bounds.isEmpty()
    ? new THREE.Vector3()
    : bounds.getCenter(new THREE.Vector3());
}

function measureScanBounds(
  options: { exclude?: THREE.Box3[]; precise?: boolean } = {},
): THREE.Box3 {
  return measureBounds(currentModel, options);
}

function isFullBounds(box: THREE.Box3): boolean {
  return isWithinBounds(box, originalBounds);
}

function survivingBounds(removals: THREE.Box3[]): THREE.Box3 {
  return measureScanBounds({
    exclude: removals,
    precise: isLevelled(draftLevel()),
  });
}

function frameOf(keep: THREE.Box3, removals: THREE.Box3[]): THREE.Box3 {
  return isFullBounds(keep) && removals.length
    ? survivingBounds(removals)
    : keep.clone();
}

function roundsOf(crop: Crop | null) {
  return cropRounds(crop, originalBounds);
}

function draftRounds(): { keep: THREE.Box3; removals: THREE.Box3[] } {
  const box = gizmo?.getBox() ?? draftKeep.clone();
  if (cropMode === "keep") return { keep: box, removals: draftRemovals };
  return {
    keep: draftKeep.clone(),
    removals: removalPending ? [...draftRemovals, box] : draftRemovals,
  };
}

function syncModelMatrix() {
  if (!currentModel) return;
  currentModel.updateMatrix();
  currentModel.matrixWorld.copy(currentModel.matrix);
}

function pinCentre() {
  if (!currentModel) return;
  currentModel.position
    .copy(appliedCentre)
    .applyAxisAngle(Y_AXIS, currentModel.rotation.y)
    .negate();
}

function storedCameraOffset(theta: number): THREE.Vector3 {
  return appliedCentre
    .clone()
    .sub(appliedCentre.clone().applyAxisAngle(Y_AXIS, theta));
}

function forEachScanMaterial(fn: (material: THREE.Material) => void) {
  currentModel?.traverse((child) => {
    const mesh = child as THREE.Mesh;
    if (!mesh.isMesh || !mesh.material) return;
    if (Array.isArray(mesh.material)) mesh.material.forEach(fn);
    else fn(mesh.material);
  });
}

function applyClippingToMaterials() {
  const planes = clippingActive ? cropWorldPlanes : null;
  const intersection = clipMode === "remove";
  forEachScanMaterial((material) => {
    material.clippingPlanes = planes;
    material.clipIntersection = intersection;
    material.needsUpdate = true;
  });
}

function updateCropPlanes() {
  if (!currentModel || (!clippingActive && shaderCropKey === "0:0")) return;
  syncModelMatrix();
  cropUniforms.cropToLocal.value.copy(currentModel.matrixWorld).invert();
  if (!clippingActive) return;
  for (let i = 0; i < 6; i++) {
    cropWorldPlanes[i]
      .copy(cropLocalPlanes[i])
      .applyMatrix4(currentModel.matrixWorld);
  }
}

function setClipBox(box: THREE.Box3 | null, nextMode: CropMode = "keep") {
  const wasActive = clippingActive;
  const wasMode = clipMode;
  clippingActive = box !== null;
  clipMode = nextMode;

  if (box) {
    clipBox.copy(box);
    cropLocalPlanes[0].set(new THREE.Vector3(1, 0, 0), -box.min.x);
    cropLocalPlanes[1].set(new THREE.Vector3(-1, 0, 0), box.max.x);
    cropLocalPlanes[2].set(new THREE.Vector3(0, 1, 0), -box.min.y);
    cropLocalPlanes[3].set(new THREE.Vector3(0, -1, 0), box.max.y);
    cropLocalPlanes[4].set(new THREE.Vector3(0, 0, 1), -box.min.z);
    cropLocalPlanes[5].set(new THREE.Vector3(0, 0, -1), box.max.z);
    if (nextMode === "remove")
      for (const plane of cropLocalPlanes) plane.negate();
    updateCropPlanes();
  }

  if (wasActive !== clippingActive || wasMode !== clipMode)
    applyClippingToMaterials();
}

function setShaderCrop(keep: THREE.Box3 | null, removals: THREE.Box3[]) {
  shaderKeepActive = keep !== null;
  if (keep) shaderKeep.copy(keep);
  shaderRemovals = removals.map((box) => box.clone());
  cropUniforms.cropRemoveMin.value = shaderRemovals.map((box) => box.min);
  cropUniforms.cropRemoveMax.value = shaderRemovals.map((box) => box.max);
  updateCropPlanes();

  const key = `${shaderKeepActive ? 1 : 0}:${shaderRemovals.length}`;
  if (key === shaderCropKey) return;
  shaderCropKey = key;
  forEachScanMaterial((material) => {
    material.needsUpdate = true;
  });
}

function applyCommittedClip() {
  const { keep, removals } = roundsOf(committedCrop);
  setClipBox(null);
  setShaderCrop(keep, removals);
}

function inertBox(): THREE.Box3 {
  const size = originalBounds.getSize(new THREE.Vector3());
  const step = Math.max(size.x, size.y, size.z, 1);
  const min = originalBounds.max.clone().addScalar(step);
  return new THREE.Box3(min, min.clone().addScalar(step));
}

function roundClipBox(box: THREE.Box3): THREE.Box3 {
  return cropMode === "remove" && !removalPending ? inertBox() : box;
}

function applyEditingClip() {
  if (!gizmo) return;
  const keeping = cropMode === "keep";
  setShaderCrop(
    keeping || isFullBounds(draftKeep) ? null : draftKeep,
    draftRemovals,
  );
  setClipBox(roundClipBox(gizmo.getBox()), cropMode);
}

function setGizmoBox(box: THREE.Box3) {
  settingBox = true;
  try {
    gizmo?.setBox(box);
  } finally {
    settingBox = false;
  }
}

function syncConfirmed() {
  cropConfirmed = {
    keep: isFullBounds(draftKeep) ? null : cropFromBox(draftKeep),
    removals: draftRemovals.map(cropFromBox),
  };
  for (const child of [...roundOutlines.children]) {
    const helper = child as THREE.Box3Helper;
    roundOutlines.remove(helper);
    helper.geometry.dispose();
    (helper.material as THREE.Material).dispose();
  }
  if (!cropEditing || cropTool !== "box") return;
  for (const box of draftRemovals) {
    const helper = new THREE.Box3Helper(box.clone(), 0xffffff);
    const material = helper.material as THREE.LineBasicMaterial;
    material.transparent = true;
    material.opacity = 0.45;
    material.toneMapped = false;
    roundOutlines.add(helper);
  }
}

function syncRoundOutlines() {
  if (!currentModel || !roundOutlines.children.length) return;
  roundOutlines.matrix.copy(currentModel.matrixWorld);
  roundOutlines.matrixWorldNeedsUpdate = true;
}

function startRemovalRound() {
  removalPending = false;
  const centre = draftKeep.getCenter(new THREE.Vector3());
  const size = draftKeep.getSize(new THREE.Vector3()).multiplyScalar(0.25);
  setGizmoBox(new THREE.Box3().setFromCenterAndSize(centre, size));
}

function syncPovGuide(frame?: THREE.Box3) {
  if (!gizmo) return;
  if (frame) draftFrame.copy(frame);
  else {
    const { keep, removals } = draftRounds();
    draftFrame.copy(frameOf(keep, removals));
  }
  if (draftFrame.isEmpty()) return;

  const wanted = draftFrame.getCenter(new THREE.Vector3());
  wanted.y = draftPovY ?? wanted.y + DEFAULT_POV_RISE;
  if (draftPovXZ) {
    wanted.x = draftPovXZ.x;
    wanted.z = draftPovXZ.z;
  }
  const seated = gizmo.setShaft(draftFrame, wanted);
  if (draftPovY != null) draftPovY = seated.y;
  if (draftPovXZ) draftPovXZ = { x: seated.x, z: seated.z };
}

function computeCropRoundPending(): boolean {
  if (!cropReady || cropTool !== "box") return false;
  if (cropMode === "remove") return removalPending;
  if (!cropDraft) return false;
  const keep = cropConfirmed.keep;
  const box = boxFromCrop(cropDraft);
  return keep ? !sameBox(box, boxFromCrop(keep)) : !isFullBounds(box);
}

function cropHasChanges(): boolean {
  if (!gizmo || !cropReady) return false;
  if (rotationOf(committedCrop).angleTo(draftRotation) > ROTATION_EPSILON)
    return true;

  const draft = draftRounds();
  const stored = roundsOf(committedCrop);
  if (!sameBox(draft.keep, stored.keep ?? originalBounds)) return true;
  if (
    draft.removals.length !== stored.removals.length ||
    draft.removals.some((box, i) => !sameBox(box, stored.removals[i]))
  )
    return true;

  const epsilon = 1e-4;
  const before = committedCrop?.povY ?? null;
  if ((before == null) !== (draftPovY == null)) return true;
  if (
    before != null &&
    draftPovY != null &&
    Math.abs(before - draftPovY) > epsilon
  )
    return true;

  const povX = committedCrop?.povX;
  const povZ = committedCrop?.povZ;
  const beforeXZ = povX != null && povZ != null ? { x: povX, z: povZ } : null;
  if ((beforeXZ == null) !== (draftPovXZ == null)) return true;
  return (
    beforeXZ != null &&
    draftPovXZ != null &&
    Math.hypot(beforeXZ.x - draftPovXZ.x, beforeXZ.z - draftPovXZ.z) > epsilon
  );
}

function toDraftSpace(
  point: THREE.Vector3,
  out = new THREE.Vector3(),
): THREE.Vector3 {
  out.copy(point);
  if (!cropEditing) return out;
  relativeRotation.copy(committedRotation).invert().premultiply(draftRotation);
  if (relativeRotation.angleTo(IDENTITY) <= ROTATION_EPSILON) return out;
  return out.sub(draftPivot).applyQuaternion(relativeRotation).add(draftPivot);
}

function countStrandedAnnotations(): number {
  if (!cropEditing || !cropReady || !annotations.length) return 0;
  const { keep, removals } = draftRounds();
  const pt = new THREE.Vector3();
  let count = 0;
  for (const a of annotations) {
    toDraftSpace(new THREE.Vector3(a.pointX, a.pointY, a.pointZ), pt);
    if (!keep.containsPoint(pt) || removals.some((r) => r.containsPoint(pt))) {
      count++;
    }
  }
  return count;
}

function emitCropState(boxResetNotice?: boolean) {
  postStageEvent({
    type: "cropState",
    editing: cropEditing,
    ready: cropReady,
    tool: cropTool,
    mode: cropMode,
    hasChanges: cropHasChanges(),
    roundPending: computeCropRoundPending(),
    emptiesScan: cropEmptiesScan,
    rotateDegrees,
    strandedCount: countStrandedAnnotations(),
    ...(boxResetNotice ? { boxResetNotice: true } : {}),
  });
}

function firstVisibleHit(
  hits: THREE.Intersection[],
): THREE.Intersection | undefined {
  if (!currentModel || (!clippingActive && shaderCropKey === "0:0"))
    return hits[0];
  const local = new THREE.Vector3();
  return hits.find((hit) => {
    local.copy(hit.point);
    currentModel!.worldToLocal(local);
    if (
      clippingActive &&
      clipBox.containsPoint(local) !== (clipMode === "keep")
    )
      return false;
    if (shaderKeepActive && !shaderKeep.containsPoint(local)) return false;
    return !shaderRemovals.some((box) => box.containsPoint(local));
  });
}

function frameOn(box: THREE.Box3) {
  if (!currentModel) return;
  const centre = box.getCenter(new THREE.Vector3());
  const size = box.getSize(new THREE.Vector3());

  appliedBox.copy(box);
  appliedCentre.copy(centre);
  pinCentre();
  modelRadius = (Math.max(size.x, size.y, size.z) || 1) / 2;

  if (!camera || !controls) return;

  const maxDim = Math.max(size.x, size.y, size.z) || 1;
  const fovRad = (camera.fov * Math.PI) / 180;
  const distance = (maxDim / 2 / Math.tan(fovRad / 2)) * 1.4;
  orbitDistance = distance;

  camera.near = Math.max(distance / 1000, 0.01);
  camera.far = distance * 100;
  controls.minDistance = distance * 0.005;

  if (mode === "pov") {
    controls.enabled = false;
    camera.fov = povState.fov;
    povPosition(camera.position);
    povState.rotationX = 0;
    povState.rotationY = 0;
    applyPovRotation();
  } else {
    controls.enabled = true;
    camera.position.set(distance * 0.7, distance * 0.5, distance * 0.8);
    controls.target.set(0, 0, 0);
    controls.update();
  }
  camera.updateProjectionMatrix();
}

function frameWholeBox(box: THREE.Box3) {
  if (!camera || !controls || !currentModel) return;
  syncModelMatrix();

  const sphere = box.getBoundingSphere(new THREE.Sphere());
  sphere.center.applyMatrix4(currentModel.matrixWorld);

  const vertical = (camera.fov * Math.PI) / 180;
  const horizontal = 2 * Math.atan(Math.tan(vertical / 2) * camera.aspect);
  const distance =
    (sphere.radius / Math.sin(Math.min(vertical, horizontal) / 2)) *
    CROP_FRAME_MARGIN;

  const direction = camera.position.clone().sub(controls.target);
  if (direction.lengthSq() < 1e-8) direction.set(0.7, 0.5, 0.8);
  direction.normalize();

  controls.target.copy(sphere.center);
  camera.position.copy(sphere.center).addScaledVector(direction, distance);
  camera.far = Math.max(camera.far, distance * 10);
  camera.updateProjectionMatrix();
  controls.update();
}

function setMode(next: CameraMode) {
  if (!camera || !controls) return;
  mode = next;
  if (next === "orbit") {
    controls.enabled = true;
    camera.fov = 70;
    camera.position.set(
      orbitDistance * 0.7,
      orbitDistance * 0.5,
      orbitDistance * 0.8,
    );
    controls.target.set(0, 0, 0);
    controls.update();
  } else {
    controls.enabled = false;
    camera.fov = povState.fov;
    povPosition(camera.position);
    povState.rotationX = 0;
    povState.rotationY = 0;
    applyPovRotation();
  }
  camera.updateProjectionMatrix();
  postStageEvent({ type: "modeChanged", mode });
}

function rebuildMarkerDOM() {
  markersLayer.innerHTML = "";
  markerElements.clear();
  for (const ann of annotations) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "marker-pin";
    if (ann.id === selectedAnnotationId) btn.classList.add("active");
    btn.textContent = String(ann.number);
    btn.addEventListener("pointerdown", (e) => e.stopPropagation());
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      selectedAnnotationId = ann.id;
      updateMarkerActiveClass();
      flyToAnnotation(ann);
      postStageEvent({ type: "annotationTapped", id: ann.id });
    });
    markersLayer.appendChild(btn);
    markerElements.set(ann.id, btn);
  }
}

function updateMarkerActiveClass() {
  for (const [id, el] of markerElements.entries()) {
    el.classList.toggle("active", id === selectedAnnotationId);
  }
}

const markerScratch = new THREE.Vector3();
function updateMarkersProjection() {
  if (!markersVisible || !currentModel || !camera || !renderer) {
    markersLayer.style.display = "none";
    return;
  }
  markersLayer.style.display = "block";
  const w = renderer.domElement.clientWidth;
  const h = renderer.domElement.clientHeight;
  for (const ann of annotations) {
    const el = markerElements.get(ann.id);
    if (!el) continue;
    markerScratch.set(ann.pointX, ann.pointY, ann.pointZ);
    const worldPoint = toDraftSpace(markerScratch);
    currentModel.localToWorld(worldPoint);
    const ndc = worldPoint.project(camera);
    if (ndc.z >= 1 || ndc.z < -1) {
      el.style.display = "none";
      continue;
    }
    const x = (ndc.x * 0.5 + 0.5) * w;
    const y = (-ndc.y * 0.5 + 0.5) * h;
    el.style.display = "block";
    el.style.transform = `translate3d(${x.toFixed(1)}px, ${y.toFixed(1)}px, 0)`;
  }
}

async function loadScan(
  url: string,
  slug: string | null,
  crop: Crop | null,
  nextAnnotations: StageAnnotation[],
  initialSelectedId: number | null = null,
) {
  if (!scene) return;
  if (cropEditing) cancelCrop();

  currentSlug = slug;
  annotations = nextAnnotations;
  selectedAnnotationId = initialSelectedId;
  rebuildMarkerDOM();

  postStageEvent({ type: "scanLoading", slug });
  userInteracted = false;
  const myId = ++loadId;

  if (currentModel) {
    scene.remove(currentModel);
    disposeObject(currentModel);
    currentModel = null;
  }

  try {
    const loader = new GLTFLoader();
    loader.setDRACOLoader(getDracoLoader());
    const gltf = await loader.loadAsync(url);
    if (myId !== loadId) return;

    currentModel = new THREE.Group();
    levelNode = new THREE.Group();
    levelNode.add(gltf.scene);
    currentModel.add(levelNode);
    scene.add(currentModel);

    committedCrop = crop;
    committedRotation.copy(rotationOf(crop));
    if (crop?.level) {
      const { pivot } = crop.level;
      applyLevel(
        rotationOf(crop),
        new THREE.Vector3(pivot.x, pivot.y, pivot.z),
      );
    }

    originalBounds.copy(measureScanBounds());
    applyCommittedClip();
    applySharedFlatMaterials(currentModel, shading);
    frameOn(crop ? boxFromCrop(crop.frame) : originalBounds);

    postStageEvent({ type: "scanLoaded", slug });
  } catch (e) {
    if (myId === loadId) {
      const rateLimited =
        (e as { response?: Response }).response?.status === 429;
      const message = (e as Error).message ?? "Failed to load scan";
      postStageEvent({ type: "scanError", message, rateLimited });
    }
  }
}

function clearScan() {
  loadId++;
  if (cropEditing) cancelCrop();
  if (scene && currentModel) {
    scene.remove(currentModel);
    disposeObject(currentModel);
    currentModel = null;
  }
  annotations = [];
  selectedAnnotationId = null;
  rebuildMarkerDOM();
}

function startCrop() {
  if (!gizmo || !currentModel || !camera || !controls) return;
  createMode = false;
  canvas.classList.remove("create-mode");
  cropEditing = true;
  cropReady = false;
  userInteracted = true;

  viewBeforeCrop = {
    mode,
    fov: camera.fov,
    position: camera.position.clone(),
    target: controls.target.clone(),
    rotationX: povState.rotationX,
    rotationY: povState.rotationY,
  };

  const token = ++cropStartToken;
  emitCropState();
  setTimeout(() => setUpCropScene(token), 32);
}

function setUpCropScene(token: number) {
  if (token !== cropStartToken || !cropEditing || !gizmo || !currentModel)
    return;
  if (mode === "pov") setMode("orbit");

  const level = committedCrop?.level;
  draftRotation.copy(rotationOf(committedCrop));
  if (level) draftPivot.set(level.pivot.x, level.pivot.y, level.pivot.z);
  else draftPivot.copy(rawCentre());
  rotationAtDragStart.copy(draftRotation);
  rotationAtToolStart.copy(draftRotation);
  cropTool = "box";
  rotateDegrees = null;
  if (level) originalBounds.copy(measureScanBounds({ precise: true }));

  const { keep, removals } = roundsOf(committedCrop);
  draftKeep.copy(keep ?? originalBounds);
  draftRemovals = removals;
  const reopened = committedCrop?.mode === "remove" ? removals.pop() : null;
  cropMode = reopened ? "remove" : "keep";
  removalPending = Boolean(reopened);
  const initial = reopened ?? draftKeep.clone();

  draftPovY = committedCrop?.povY ?? null;
  draftPovXZ =
    committedCrop?.povX != null && committedCrop.povZ != null
      ? { x: committedCrop.povX, z: committedCrop.povZ }
      : null;

  gizmo.show(initial, originalBounds);
  applyEditingClip();
  syncConfirmed();
  syncPovGuide(committedCrop ? boxFromCrop(committedCrop.frame) : undefined);
  frameWholeBox(draftKeep);
  cropDraft = cropFromBox(initial);
  cropEmptiesScan = wouldEmptyScan(initial);
  cropReady = true;
  emitCropState();
}

function clearDraft() {
  cropDraft = null;
  cropEmptiesScan = false;
  cropMode = "keep";
  removalPending = false;
  draftRemovals = [];
  draftPovY = null;
  draftPovXZ = null;
  cropTool = "box";
  rotateDegrees = null;
  syncConfirmed();
}

function restoreViewBeforeCrop() {
  const view = viewBeforeCrop;
  viewBeforeCrop = null;
  if (!view || !camera || !controls) return;
  if (view.mode === "pov") {
    setMode("pov");
    povState.fov = view.fov;
    camera.fov = view.fov;
    povState.rotationX = view.rotationX;
    povState.rotationY = view.rotationY;
    applyPovRotation();
  } else {
    camera.fov = view.fov;
    camera.position.copy(view.position);
    controls.target.copy(view.target);
    controls.update();
  }
  camera.updateProjectionMatrix();
}

function cancelCrop() {
  if (!gizmo) return;
  cropStartToken++;
  cropReady = false;
  cropEditing = false;
  gizmo.hide();
  clearDraft();

  const savedRot = rotationOf(committedCrop);
  if (savedRot.angleTo(draftRotation) > ROTATION_EPSILON) {
    const pivot = committedCrop?.level?.pivot;
    applyLevel(
      savedRot,
      pivot ? new THREE.Vector3(pivot.x, pivot.y, pivot.z) : draftPivot,
    );
    draftRotation.copy(savedRot);
    originalBounds.copy(
      measureScanBounds({ precise: Boolean(committedCrop?.level) }),
    );
  }
  applyCommittedClip();
  restoreViewBeforeCrop();
  emitCropState();
}

function resetCropBox() {
  if (!gizmo || !cropReady) return;
  cropMode = "keep";
  removalPending = false;
  draftPovY = null;
  draftPovXZ = null;
  rotateDegrees = null;

  const wasTurned =
    draftRotation.angleTo(new THREE.Quaternion()) > ROTATION_EPSILON;
  draftRotation.identity();
  rotationAtDragStart.identity();
  rotationAtToolStart.identity();
  if (wasTurned) {
    applyLevel(draftRotation, draftPivot);
    originalBounds.copy(measureScanBounds());
  }

  cropTool = "box";
  draftKeep.copy(originalBounds);
  draftRemovals = [];
  gizmo.show(originalBounds.clone(), originalBounds);
  setGizmoBox(originalBounds.clone());
  applyEditingClip();
  syncConfirmed();
  if (wasTurned) frameWholeBox(originalBounds);
  emitCropState();
}

function switchCropTool(next: CropGizmoTool) {
  if (!gizmo || !cropReady || cropTool === next) return;
  if (next === "rotate") {
    rotationAtToolStart.copy(draftRotation);
    rotationAtDragStart.copy(draftRotation);
    cropTool = "rotate";
    setClipBox(null);
    setShaderCrop(null, []);
    syncConfirmed();
    const size = originalBounds.getSize(new THREE.Vector3());
    gizmo.setTool("rotate", {
      centre: draftPivot,
      size: Math.max(size.x, size.y, size.z),
      floorY: originalBounds.min.y,
    });
    emitCropState();
    return;
  }

  cropTool = "box";
  rotateDegrees = null;
  if (rotationAtToolStart.angleTo(draftRotation) <= ROTATION_EPSILON) {
    gizmo.setTool("box");
    applyEditingClip();
    syncConfirmed();
    emitCropState();
    return;
  }

  const drawn = gizmo.getBox();
  const hadBox =
    (cropMode === "remove" && removalPending) ||
    (cropMode === "keep" && !isFullBounds(drawn)) ||
    !isFullBounds(draftKeep) ||
    draftRemovals.length > 0 ||
    draftPovY != null ||
    draftPovXZ != null;

  originalBounds.copy(measureScanBounds({ precise: true }));
  cropMode = "keep";
  removalPending = false;
  draftPovY = null;
  draftPovXZ = null;
  draftKeep.copy(originalBounds);
  draftRemovals = [];
  gizmo.show(originalBounds.clone(), originalBounds);
  setGizmoBox(originalBounds.clone());
  applyEditingClip();
  syncConfirmed();
  frameWholeBox(originalBounds);
  emitCropState(hadBox);
}

function switchCropMode(next: CropMode) {
  if (!gizmo || !cropReady || cropMode === next) return;
  if (next === "remove") {
    draftKeep.copy(gizmo.getBox());
    cropMode = "remove";
    startRemovalRound();
  } else {
    if (removalPending && !cropEmptiesScan) {
      if (draftRemovals.length >= MAX_CROP_REMOVALS - 1) return;
      draftRemovals = [...draftRemovals, gizmo.getBox()];
    }
    removalPending = false;
    cropMode = "keep";
    setGizmoBox(draftKeep.clone());
  }
  applyEditingClip();
  syncConfirmed();
  cropEmptiesScan = wouldEmptyScan(gizmo.getBox());
  syncPovGuide();
  emitCropState();
}

function confirmCropRound() {
  if (!gizmo || !cropReady || cropTool !== "box") return;
  const box = gizmo.getBox();
  if (cropMode === "keep") {
    if (sameBox(box, draftKeep)) return;
    draftKeep.copy(box);
  } else {
    if (!removalPending || cropEmptiesScan) return;
    if (draftRemovals.length >= MAX_CROP_REMOVALS - 1) return;
    draftRemovals = [...draftRemovals, box];
    startRemovalRound();
  }
  applyEditingClip();
  syncConfirmed();
  cropEmptiesScan = false;
  syncPovGuide();
  emitCropState();
}

function discardCropRound() {
  if (!gizmo || !cropReady || cropTool !== "box" || !computeCropRoundPending())
    return;
  if (cropMode === "keep") setGizmoBox(draftKeep.clone());
  else startRemovalRound();
  applyEditingClip();
  cropEmptiesScan = false;
  syncPovGuide();
  emitCropState();
}

function pendingCrop(): CropResult | null {
  if (!gizmo || !currentModel || !cropReady) return null;
  if (cropTool === "rotate") switchCropTool("box");

  const { keep, removals } = draftRounds();
  const level = draftLevel();
  const keepsAll = isFullBounds(keep);
  const cleared =
    keepsAll &&
    !removals.length &&
    draftPovY == null &&
    draftPovXZ == null &&
    !level;

  const frame = cleared ? originalBounds : frameOf(keep, removals);
  if (frame.isEmpty()) return null;

  const centreAfter = frame.getCenter(new THREE.Vector3());
  const povY =
    draftPovY == null
      ? undefined
      : clampInsideEdges(draftPovY, frame.min.y, frame.max.y);
  const povXZ = draftPovXZ && {
    x: clampInsideEdges(draftPovXZ.x, frame.min.x, frame.max.x),
    z: clampInsideEdges(draftPovXZ.z, frame.min.z, frame.max.z),
  };

  const boxes: Pick<Crop, "mode" | "box" | "removed"> =
    keepsAll && removals.length
      ? {
          mode: "remove",
          box: cropFromBox(removals[removals.length - 1]),
          ...(removals.length > 1
            ? { removed: removals.slice(0, -1).map(cropFromBox) }
            : {}),
        }
      : {
          mode: "keep",
          box: cropFromBox(keep),
          ...(removals.length ? { removed: removals.map(cropFromBox) } : {}),
        };

  return {
    crop: cleared
      ? null
      : {
          ...boxes,
          frame: cropFromBox(frame),
          ...(povY == null ? {} : { povY }),
          ...(povXZ ? { povX: povXZ.x, povZ: povXZ.z } : {}),
          ...(level ? { level } : {}),
        },
    centreBefore: {
      x: appliedCentre.x,
      y: appliedCentre.y,
      z: appliedCentre.z,
    },
    centreAfter: { x: centreAfter.x, y: centreAfter.y, z: centreAfter.z },
  };
}

function captureThumb(): string | null {
  if (!scene || !currentModel) return null;
  const offCanvas = document.createElement("canvas");
  offCanvas.width = 800;
  offCanvas.height = 800;
  let offRenderer: THREE.WebGLRenderer | null = null;
  try {
    offRenderer = new THREE.WebGLRenderer({
      canvas: offCanvas,
      antialias: true,
    });
    offRenderer.setPixelRatio(1);
    offRenderer.setSize(800, 800, false);
    offRenderer.setClearColor(0x000000);
    offRenderer.toneMapping = THREE.NoToneMapping;
    offRenderer.outputColorSpace = THREE.SRGBColorSpace;
    offRenderer.localClippingEnabled = true;

    const thumbCam = new THREE.PerspectiveCamera(70, 1, 0.01, 1000);
    const size = appliedBox.getSize(new THREE.Vector3());
    const maxDim = Math.max(size.x, size.y, size.z) || 1;
    const fovRad = (70 * Math.PI) / 180;
    const dist = (maxDim / 2 / Math.tan(fovRad / 2)) * 1.4;
    thumbCam.position.set(dist * 0.7, dist * 0.5, dist * 0.8);
    thumbCam.near = Math.max(dist / 1000, 0.01);
    thumbCam.far = dist * 100;
    thumbCam.lookAt(0, 0, 0);
    thumbCam.updateProjectionMatrix();

    const savedRotY = currentModel.rotation.y;
    currentModel.rotation.y = 0;
    pinCentre();
    updateCropPlanes();
    offRenderer.render(scene, thumbCam);
    const dataUrl = offCanvas.toDataURL("image/jpeg", 0.85);
    currentModel.rotation.y = savedRotY;
    pinCentre();
    updateCropPlanes();
    return dataUrl;
  } finally {
    offRenderer?.dispose();
  }
}

function applyCommittedCrop(result: CropResult) {
  if (!gizmo || !currentModel) return;
  committedCrop = result.crop;
  committedRotation.copy(rotationOf(result.crop));
  applyCommittedClip();
  viewBeforeCrop = null;
  frameOn(result.crop ? boxFromCrop(result.crop.frame) : originalBounds);

  cropEditing = false;
  cropReady = false;
  gizmo.hide();
  clearDraft();
  emitCropState();
}

function commitCrop() {
  if (!cropHasChanges()) {
    cancelCrop();
    postStageEvent({ type: "cropResult", result: null, thumbDataUrl: null });
    return;
  }
  const result = pendingCrop();
  if (!result) {
    postStageEvent({ type: "cropResult", result: null, thumbDataUrl: null });
    return;
  }
  applyCommittedCrop(result);
  const thumbDataUrl = captureThumb();
  postStageEvent({ type: "cropResult", result, thumbDataUrl });
}

function pickPoint(clientX: number, clientY: number): THREE.Vector3 | null {
  if (!camera || !renderer || !currentModel) return null;
  const rect = renderer.domElement.getBoundingClientRect();
  const ndcX = ((clientX - rect.left) / rect.width) * 2 - 1;
  const ndcY = -((clientY - rect.top) / rect.height) * 2 + 1;
  const raycaster = new THREE.Raycaster();
  raycaster.setFromCamera(new THREE.Vector2(ndcX, ndcY), camera);
  const hit = firstVisibleHit(raycaster.intersectObject(currentModel, true));
  if (!hit) return null;
  return currentModel.worldToLocal(hit.point.clone());
}

function reanchorOrbitTarget(force = false) {
  if (!camera || !controls || !currentModel) return;
  if (mode !== "orbit" || tweenActive || cropEditing) return;

  const radius = camera.position.distanceTo(controls.target);
  const maxWanted = orbitDistance * 2;
  if (radius * PROBE_RATIO > maxWanted) return;

  const now = performance.now();
  if (!force && now - lastProbeAt < PROBE_INTERVAL_MS) return;
  lastProbeAt = now;

  camera.getWorldDirection(probeDir);
  probeRaycaster.set(camera.position, probeDir);
  probeRaycaster.near = 0;
  probeRaycaster.far = orbitDistance * 4;
  const hit = firstVisibleHit(
    probeRaycaster.intersectObject(currentModel, true),
  );
  const surfaceDistance = hit ? hit.distance : modelRadius;
  const wanted = Math.min(surfaceDistance, maxWanted);
  if (!(wanted > 0) || wanted < radius * PROBE_RATIO) return;
  controls.target.copy(camera.position).addScaledVector(probeDir, wanted);
}

function getCameraSnapshot(): CameraSnapshot {
  const modelRotationY = currentModel?.rotation.y ?? 0;
  if (!camera) {
    return { cameraMode: "orbit", cameraFov: 70, modelRotationY };
  }
  if (mode === "orbit") {
    const offset = storedCameraOffset(modelRotationY);
    const position = camera.position.clone().sub(offset);
    const target = (controls?.target.clone() ?? new THREE.Vector3()).sub(
      offset,
    );
    return {
      cameraMode: "orbit",
      cameraFov: camera.fov,
      modelRotationY,
      orbitPosX: position.x,
      orbitPosY: position.y,
      orbitPosZ: position.z,
      orbitTargetX: target.x,
      orbitTargetY: target.y,
      orbitTargetZ: target.z,
    };
  }
  return {
    cameraMode: "pov",
    cameraFov: camera.fov,
    modelRotationY,
    rotationX: povState.rotationX,
    rotationY: povState.rotationY,
  };
}

function easeInOut(t: number): number {
  return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
}

function flyToAnnotation(ann: StageAnnotation, duration = 800) {
  if (!camera || !controls) return;
  cancelAnimationFrame(tweenRaf);
  tweenActive = true;
  controls.enabled = false;

  if (ann.cameraMode !== mode) {
    mode = ann.cameraMode;
    postStageEvent({ type: "modeChanged", mode });
    if (ann.cameraMode === "pov") {
      povPosition(camera.position);
      povState.rotationX = ann.rotationX ?? 0;
      povState.rotationY = ann.rotationY ?? 0;
      applyPovRotation();
    }
  }

  const startPos = camera.position.clone();
  const startTarget = controls.target.clone();
  const startFov = camera.fov;
  const startRotX = povState.rotationX;
  const startRotY = povState.rotationY;
  const startModelRotY = currentModel?.rotation.y ?? 0;
  const startTime = performance.now();

  const targetModelRotY = ann.modelRotationY ?? startModelRotY;
  let deltaModelRotY = targetModelRotY - startModelRotY;
  while (deltaModelRotY > Math.PI) deltaModelRotY -= Math.PI * 2;
  while (deltaModelRotY < -Math.PI) deltaModelRotY += Math.PI * 2;

  let targetPos: THREE.Vector3;
  let targetTarget: THREE.Vector3;
  const targetFov = ann.cameraFov;
  let targetRotX = startRotX;
  let targetRotY = startRotY;

  if (ann.cameraMode === "orbit") {
    targetPos = new THREE.Vector3(
      ann.orbitPosX ?? 0,
      ann.orbitPosY ?? 0,
      ann.orbitPosZ ?? 4,
    );
    targetTarget = new THREE.Vector3(
      ann.orbitTargetX ?? 0,
      ann.orbitTargetY ?? 0,
      ann.orbitTargetZ ?? 0,
    );
    const offset = storedCameraOffset(targetModelRotY);
    targetPos.add(offset);
    targetTarget.add(offset);
  } else {
    targetPos = povPosition(new THREE.Vector3(), targetModelRotY);
    targetTarget = new THREE.Vector3(0, 0, 0);
    targetRotX = ann.rotationX ?? 0;
    targetRotY = ann.rotationY ?? 0;
  }

  function tick() {
    const elapsed = performance.now() - startTime;
    const t = Math.min(elapsed / duration, 1);
    const e = easeInOut(t);
    if (!camera) return;

    camera.position.lerpVectors(startPos, targetPos, e);
    camera.fov = startFov + (targetFov - startFov) * e;
    camera.updateProjectionMatrix();

    if (currentModel) {
      currentModel.rotation.y = startModelRotY + deltaModelRotY * e;
      pinCentre();
    }

    if (ann.cameraMode === "pov") {
      povState.rotationX = startRotX + (targetRotX - startRotX) * e;
      povState.rotationY = startRotY + (targetRotY - startRotY) * e;
      applyPovRotation();
    } else if (controls) {
      controls.target.lerpVectors(startTarget, targetTarget, e);
      camera.lookAt(controls.target);
    }

    if (t < 1) {
      tweenRaf = requestAnimationFrame(tick);
    } else {
      tweenActive = false;
      userInteracted = true;
      if (ann.cameraMode === "orbit" && controls) {
        controls.enabled = true;
        controls.target.copy(targetTarget);
        const hadDamping = controls.enableDamping;
        controls.enableDamping = false;
        controls.update();
        controls.enableDamping = hadDamping;
        camera.position.copy(targetPos);
        camera.lookAt(controls.target);
        controls.update();
      }
    }
  }

  tweenRaf = requestAnimationFrame(tick);
}

function sizeToContainer() {
  if (!renderer || !camera) return;
  const parent = canvas.parentElement;
  const w = parent?.clientWidth ?? canvas.clientWidth;
  const h = parent?.clientHeight ?? canvas.clientHeight;
  const pr = renderer.getPixelRatio();
  const targetW = Math.round(w * pr);
  const targetH = Math.round(h * pr);
  if (
    renderer.domElement.width !== targetW ||
    renderer.domElement.height !== targetH
  ) {
    renderer.setSize(w, h, false);
    camera.aspect = w / Math.max(h, 1);
    camera.updateProjectionMatrix();
  }
}

function onPointerDown(e: PointerEvent) {
  activePointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
  pointerDownX = e.clientX;
  pointerDownY = e.clientY;
  if (gizmo?.onPointerDown(e)) {
    (e.currentTarget as Element | null)?.setPointerCapture?.(e.pointerId);
    return;
  }
  if (mode === "orbit") {
    reanchorOrbitTarget(true);
  }
  if (mode !== "pov" || tweenActive) return;
  if (activePointers.size === 2) {
    povState.dragging = false;
    pinchStartDist = getPinchDist();
    pinchStartFov = povState.fov;
  } else {
    povState.dragging = true;
    povState.lastX = e.clientX;
    povState.lastY = e.clientY;
  }
}

function onPointerMove(e: PointerEvent) {
  activePointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
  if (gizmo?.onPointerMove(e)) return;
  if (mode !== "pov" || !camera || tweenActive) return;
  if (activePointers.size >= 2) {
    const dist = getPinchDist();
    if (pinchStartDist > 0) {
      povState.fov = Math.max(
        30,
        Math.min(110, pinchStartFov * (pinchStartDist / dist)),
      );
      camera.fov = povState.fov;
      camera.updateProjectionMatrix();
    }
    return;
  }
  if (!povState.dragging) return;
  const dx = e.clientX - povState.lastX;
  const dy = e.clientY - povState.lastY;
  povState.rotationY += dx * 0.005;
  povState.rotationX += dy * 0.005;
  applyPovRotation();
  povState.lastX = e.clientX;
  povState.lastY = e.clientY;
}

function onPointerUp(e: PointerEvent) {
  activePointers.delete(e.pointerId);
  const wasCropDrag = gizmo?.onPointerUp() ?? false;
  const dx = Math.abs(e.clientX - pointerDownX);
  const dy = Math.abs(e.clientY - pointerDownY);
  const isClick = dx < 6 && dy < 6;

  if (wasCropDrag) {
    emitCropState();
    return;
  }

  if (createMode && isClick && !tweenActive) {
    const pt = pickPoint(e.clientX, e.clientY);
    if (pt) {
      postStageEvent({
        type: "pointPicked",
        point: { x: pt.x, y: pt.y, z: pt.z },
        snapshot: getCameraSnapshot(),
      });
    }
  }
  povState.dragging = false;
}

function onPointerCancel(e: PointerEvent) {
  activePointers.delete(e.pointerId);
  povState.dragging = false;
}

function animate() {
  requestAnimationFrame(animate);
  sizeToContainer();
  if (mode === "orbit" && controls) {
    if (!userInteracted && !cropEditing && currentModel) {
      currentModel.rotation.y += 0.001;
      pinCentre();
    }
    if (!tweenActive) controls.update();
  }
  updateCropPlanes();
  syncRoundOutlines();
  gizmo?.update();
  if (renderer && scene && camera) {
    renderer.render(scene, camera);
    updateMarkersProjection();
  }
}

function init() {
  renderer = new THREE.WebGLRenderer({
    canvas,
    antialias: true,
    powerPreference: "high-performance",
  });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setClearColor(0x000000);
  renderer.toneMapping = THREE.NoToneMapping;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.localClippingEnabled = true;

  scene = new THREE.Scene();
  scene.add(roundOutlines);

  camera = new THREE.PerspectiveCamera(70, 1, 0.01, 1000);
  camera.rotation.order = "YXZ";
  camera.position.set(0, 0, 4);

  controls = new OrbitControls(camera, canvas);
  controls.enableDamping = true;
  controls.dampingFactor = 0.08;
  controls.addEventListener("start", () => {
    userInteracted = true;
  });

  gizmo = createCropGizmo({
    scene,
    camera,
    renderer,
    controls,
    getModel: () => currentModel,
    onChange: (box) => {
      if (!settingBox && cropMode === "remove") removalPending = true;
      setClipBox(roundClipBox(box), cropMode);
      cropDraft = cropFromBox(box);
      cropEmptiesScan = wouldEmptyScan(box);
      if (cropMode === "keep") syncPovGuide(box);
      emitCropState();
    },
    onPovChange: (y) => {
      draftPovY = y;
      emitCropState();
    },
    onShaftMove: (x, z) => {
      draftPovXZ = { x, z };
      emitCropState();
    },
    onRotate: (axis, angle) => {
      draftRotation
        .setFromAxisAngle(AXES[axis], angle)
        .multiply(rotationAtDragStart);
      applyLevel(draftRotation, draftPivot);
      rotateDegrees = (angle * 180) / Math.PI;
      emitCropState();
    },
    onRotateEnd: () => {
      rotationAtDragStart.copy(draftRotation);
      rotateDegrees = null;
      const floor = measureScanBounds({ precise: true });
      if (!floor.isEmpty()) gizmo?.setGridFloor(floor.min.y);
      emitCropState();
    },
    onDragEnd: () => {
      if (cropMode === "remove" || draftRemovals.length) syncPovGuide();
      emitCropState();
    },
  });

  sizeToContainer();
  canvas.addEventListener("pointerdown", onPointerDown);
  canvas.addEventListener("pointermove", onPointerMove);
  window.addEventListener("pointerup", onPointerUp);
  window.addEventListener("pointercancel", onPointerCancel);
  canvas.addEventListener("dragstart", (e) => e.preventDefault());

  animate();
  postStageEvent({ type: "ready" });
}

function dispatch(raw: StageCommand | string) {
  const cmd: StageCommand = typeof raw === "string" ? JSON.parse(raw) : raw;
  switch (cmd.type) {
    case "loadScan":
      void loadScan(
        cmd.url,
        cmd.slug,
        cmd.crop,
        cmd.annotations,
        cmd.selectedAnnotationId ?? null,
      );
      break;
    case "clearScan":
      clearScan();
      break;
    case "setMode":
      setMode(cmd.mode);
      break;
    case "setAnnotations":
      annotations = cmd.annotations;
      selectedAnnotationId = cmd.selectedId;
      rebuildMarkerDOM();
      break;
    case "selectAnnotation": {
      selectedAnnotationId = cmd.id;
      updateMarkerActiveClass();
      if (cmd.fly && cmd.id != null) {
        const ann = annotations.find((a) => a.id === cmd.id);
        if (ann) flyToAnnotation(ann);
      }
      break;
    }
    case "setMarkersVisible":
      markersVisible = cmd.visible;
      break;
    case "setCreateMode":
      createMode = cmd.active;
      canvas.classList.toggle("create-mode", createMode);
      break;
    case "startCrop":
      startCrop();
      break;
    case "cancelCrop":
      cancelCrop();
      break;
    case "resetCrop":
      resetCropBox();
      break;
    case "setCropMode":
      switchCropMode(cmd.mode);
      break;
    case "setCropTool":
      switchCropTool(cmd.tool);
      break;
    case "confirmCropRound":
      confirmCropRound();
      break;
    case "discardCropRound":
      discardCropRound();
      break;
    case "commitCrop":
      commitCrop();
      break;
    case "applyCommittedCrop":
      applyCommittedCrop(cmd.result);
      break;
  }
}

window.ArchiveStage = { dispatch };
init();
