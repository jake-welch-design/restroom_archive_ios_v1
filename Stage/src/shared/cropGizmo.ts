import * as THREE from "three";
import type { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { LineSegments2 } from "three/examples/jsm/lines/LineSegments2.js";
import { LineSegmentsGeometry } from "three/examples/jsm/lines/LineSegmentsGeometry.js";
import { LineMaterial } from "three/examples/jsm/lines/LineMaterial.js";
import { MIN_CROP_SIZE } from "./crop";

const HANDLE_VISIBLE_PX = 16;
const HANDLE_HIT_PX = 28;
const POV_VISIBLE_PX = 20;
const POV_HIT_PX = 32;
const SHAFT_WIDTH_PX = 2;
const SHAFT_HIT_PX = 10;
const SHAFT_LEVEL_VIEW = 0.2;
export const POV_EDGE_MARGIN = 0.05;

export function clampInsideEdges(v: number, min: number, max: number): number {
  const low = min + POV_EDGE_MARGIN;
  const high = max - POV_EDGE_MARGIN;
  if (low > high) return (min + max) / 2;
  return Math.min(Math.max(v, low), high);
}

const BRACKET_WIDTH_PX = 3;
const EDGE_WIDTH_PX = 1;
const BRACKET_FRACTION = 0.16;
const BRACKET_MAX_FRACTION = 0.38;
const WHITE = 0xffffff;
const ACCENT = 0xff0000;
const WALL_OPACITY = 0.1;
const WALL_DRAG_OPACITY = 0.24;

const RING_SEGMENTS = 96;
const RING_WIDTH_PX = 2;
const RING_HIT_PX = 14;
const RING_RADIUS_FACTOR = 0.6;
const GRID_DIVISIONS = 10;
const GRID_REACH = 1.15;
const SNAP_STEP = Math.PI / 2;
const SNAP_WITHIN = (3 * Math.PI) / 180;
const FACE_ON_FACING = 0.75;

export type RotateAxis = "x" | "y" | "z";
export type CropGizmoTool = "box" | "rotate";

const FACES = [
  { axis: "x", end: "min" },
  { axis: "x", end: "max" },
  { axis: "y", end: "min" },
  { axis: "y", end: "max" },
  { axis: "z", end: "min" },
  { axis: "z", end: "max" },
] as const;

type Axis = (typeof FACES)[number]["axis"];
type FaceEnd = (typeof FACES)[number]["end"];

interface Face {
  axis: Axis;
  end: FaceEnd;
  handle: THREE.Sprite;
  wall: THREE.Mesh<THREE.PlaneGeometry, THREE.MeshBasicMaterial>;
}

type Grip = Face | "pov" | "shaft";

export interface CropGizmoDeps {
  scene: THREE.Scene;
  camera: THREE.PerspectiveCamera;
  renderer: THREE.WebGLRenderer;
  controls: OrbitControls;
  getModel: () => THREE.Object3D | null;
  onChange: (box: THREE.Box3) => void;
  onPovChange: (y: number) => void;
  onShaftMove: (x: number, z: number) => void;
  onDragEnd: () => void;
  onRotate: (axis: RotateAxis, angle: number) => void;
  onRotateEnd: () => void;
}

function createHandleTexture(): THREE.CanvasTexture {
  const size = 64;
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d");
  if (ctx) {
    const centre = size / 2;
    const outer = (size * (HANDLE_VISIBLE_PX / HANDLE_HIT_PX)) / 2;
    const ring = outer * 0.2;
    ctx.beginPath();
    ctx.arc(centre, centre, outer, 0, Math.PI * 2);
    ctx.fillStyle = "#000";
    ctx.fill();
    ctx.beginPath();
    ctx.arc(centre, centre, outer - ring, 0, Math.PI * 2);
    ctx.fillStyle = "#fff";
    ctx.fill();
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

function createPovTexture(): THREE.CanvasTexture {
  const size = 64;
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d");
  if (ctx) {
    const centre = size / 2;
    const outer = (size * (POV_VISIBLE_PX / POV_HIT_PX)) / 2;
    ctx.beginPath();
    ctx.arc(centre, centre, outer, 0, Math.PI * 2);
    ctx.fillStyle = "#000";
    ctx.fill();
    ctx.beginPath();
    ctx.arc(centre, centre, outer * 0.8, 0, Math.PI * 2);
    ctx.fillStyle = "#fff";
    ctx.fill();
    ctx.beginPath();
    ctx.arc(centre, centre, outer * 0.32, 0, Math.PI * 2);
    ctx.fillStyle = "#000";
    ctx.fill();
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

function createLines(segments: number, width: number, opacity: number) {
  const geometry = new LineSegmentsGeometry();
  geometry.setPositions(new Float32Array(segments * 6));
  const material = new LineMaterial({
    color: WHITE,
    linewidth: width,
    transparent: true,
    opacity,
    depthTest: false,
    depthWrite: false,
  });
  const lines = new LineSegments2(geometry, material);
  lines.frustumCulled = false;
  return lines;
}

function writeSegments(lines: LineSegments2, values: Float32Array) {
  const attribute = lines.geometry.getAttribute(
    "instanceStart",
  ) as THREE.InterleavedBufferAttribute;
  (attribute.data.array as Float32Array).set(values);
  attribute.data.needsUpdate = true;
}

export function createCropGizmo(deps: CropGizmoDeps) {
  const group = new THREE.Group();
  group.matrixAutoUpdate = false;
  group.visible = false;
  deps.scene.add(group);

  const box = new THREE.Box3();
  const bounds = new THREE.Box3();

  const edges = createLines(12, EDGE_WIDTH_PX, 0.45);
  edges.renderOrder = 2;
  group.add(edges);

  const brackets = createLines(8 * 3, BRACKET_WIDTH_PX, 1);
  brackets.renderOrder = 3;
  group.add(brackets);

  const wallGeometry = new THREE.PlaneGeometry(1, 1);
  const handleTexture = createHandleTexture();

  const faces: Face[] = FACES.map(({ axis, end }) => {
    const handle = new THREE.Sprite(
      new THREE.SpriteMaterial({
        map: handleTexture,
        color: WHITE,
        sizeAttenuation: false,
        depthTest: false,
        depthWrite: false,
        transparent: true,
      }),
    );
    handle.renderOrder = 4;
    group.add(handle);

    const wall = new THREE.Mesh(
      wallGeometry,
      new THREE.MeshBasicMaterial({
        color: WHITE,
        transparent: true,
        opacity: WALL_OPACITY,
        side: THREE.DoubleSide,
        depthWrite: false,
        polygonOffset: true,
        polygonOffsetFactor: -1,
        polygonOffsetUnits: -1,
      }),
    );
    if (axis === "x") wall.rotation.set(0, Math.PI / 2, 0);
    else if (axis === "y") wall.rotation.set(Math.PI / 2, 0, 0);
    wall.renderOrder = 1;
    group.add(wall);

    return { axis, end, handle, wall };
  });

  const handles = faces.map((f) => f.handle);
  const shaft = createLines(1, SHAFT_WIDTH_PX, 0.75);
  shaft.renderOrder = 3;
  group.add(shaft);

  const povTexture = createPovTexture();
  const povDot = new THREE.Sprite(
    new THREE.SpriteMaterial({
      map: povTexture,
      color: WHITE,
      sizeAttenuation: false,
      depthTest: false,
      depthWrite: false,
      transparent: true,
    }),
  );
  povDot.renderOrder = 5;
  group.add(povDot);

  const grips = [...handles, povDot];

  const rings: Record<RotateAxis, LineSegments2> = {
    x: createLines(RING_SEGMENTS, RING_WIDTH_PX, 0.9),
    y: createLines(RING_SEGMENTS, RING_WIDTH_PX, 0.9),
    z: createLines(RING_SEGMENTS, RING_WIDTH_PX, 0.9),
  };
  for (const ring of Object.values(rings)) {
    ring.renderOrder = 4;
    group.add(ring);
  }

  const grid = createLines((GRID_DIVISIONS + 1) * 2, 1, 0.35);
  grid.material.depthTest = true;
  grid.renderOrder = 1;
  group.add(grid);

  const boxParts: THREE.Object3D[] = [
    edges,
    brackets,
    shaft,
    povDot,
    ...faces.flatMap((f) => [f.handle, f.wall]),
  ];
  const rotateParts: THREE.Object3D[] = [...Object.values(rings), grid];

  let hovered: Grip | null = null;
  let dragging: Grip | null = null;
  let tool: CropGizmoTool = "box";
  const ringCentre = new THREE.Vector3();
  let ringRadius = 1;
  let hoveredRing: RotateAxis | null = null;

  let rotating:
    | {
        axis: RotateAxis;
        method: "circle";
        centreX: number;
        centreY: number;
        sign: number;
        previous: number;
        total: number;
      }
    | {
        axis: RotateAxis;
        method: "tangent";
        origin: THREE.Vector3;
        tangent: THREE.Vector3;
        total: number;
      }
    | null = null;
  const rotatePlane = new THREE.Plane();

  const shaftFrame = {
    x: 0,
    z: 0,
    min: new THREE.Vector3(),
    max: new THREE.Vector3(),
  };
  let povY = 0;
  const shaftValues = new Float32Array(6);
  const shaftDragStart = new THREE.Vector3();
  let shaftStartX = 0;
  let shaftStartZ = 0;

  const dragPlane = new THREE.Plane();
  let dragStartAlongAxis = 0;
  let dragStartValue = 0;

  const raycaster = new THREE.Raycaster();
  const pointer = new THREE.Vector2();
  const inverseModel = new THREE.Matrix4();
  const localRay = new THREE.Ray();
  const scratch = new THREE.Vector3();
  const localAxis = new THREE.Vector3();
  const localViewDir = new THREE.Vector3();
  const edgeValues = new Float32Array(12 * 6);
  const bracketValues = new Float32Array(8 * 3 * 6);

  function faceValue(face: Face): number {
    return (face.end === "min" ? box.min : box.max)[face.axis];
  }

  function faceCentre(face: Face, out: THREE.Vector3): THREE.Vector3 {
    box.getCenter(out);
    out[face.axis] = faceValue(face);
    return out;
  }

  function writeEdges() {
    const { min, max } = box;
    const c = [
      [min.x, min.y, min.z],
      [max.x, min.y, min.z],
      [max.x, max.y, min.z],
      [min.x, max.y, min.z],
      [min.x, min.y, max.z],
      [max.x, min.y, max.z],
      [max.x, max.y, max.z],
      [min.x, max.y, max.z],
    ];
    const pairs = [
      [0, 1],
      [1, 2],
      [2, 3],
      [3, 0],
      [4, 5],
      [5, 6],
      [6, 7],
      [7, 4],
      [0, 4],
      [1, 5],
      [2, 6],
      [3, 7],
    ];
    let i = 0;
    for (const [a, b] of pairs) {
      edgeValues.set(c[a], i);
      edgeValues.set(c[b], i + 3);
      i += 6;
    }
    writeSegments(edges, edgeValues);
  }

  function writeBrackets() {
    const size = box.getSize(scratch);
    const shortest = Math.min(size.x, size.y, size.z);

    let i = 0;
    for (const xEnd of ["min", "max"] as const)
      for (const yEnd of ["min", "max"] as const)
        for (const zEnd of ["min", "max"] as const) {
          const corner: Record<Axis, number> = {
            x: box[xEnd].x,
            y: box[yEnd].y,
            z: box[zEnd].z,
          };
          const ends: Record<Axis, FaceEnd> = { x: xEnd, y: yEnd, z: zEnd };

          for (const axis of ["x", "y", "z"] as const) {
            const length = Math.min(
              shortest * BRACKET_FRACTION,
              size[axis] * BRACKET_MAX_FRACTION,
            );
            const towardInterior = ends[axis] === "min" ? 1 : -1;
            bracketValues.set([corner.x, corner.y, corner.z], i);
            const to = { ...corner };
            to[axis] += towardInterior * length;
            bracketValues.set([to.x, to.y, to.z], i + 3);
            i += 6;
          }
        }
    writeSegments(brackets, bracketValues);
  }

  function positionHandles() {
    for (const face of faces) faceCentre(face, face.handle.position);
  }

  function writeWalls() {
    const size = box.getSize(scratch);
    for (const face of faces) {
      faceCentre(face, face.wall.position);
      if (face.axis === "x") face.wall.scale.set(size.z, size.y, 1);
      else if (face.axis === "y") face.wall.scale.set(size.x, size.z, 1);
      else face.wall.scale.set(size.x, size.y, 1);
    }
  }

  function redraw() {
    writeEdges();
    writeBrackets();
    writeWalls();
    positionHandles();
  }

  function clampPov(y: number): number {
    return clampInsideEdges(y, shaftFrame.min.y, shaftFrame.max.y);
  }

  function writeShaft() {
    const { x, z, min, max } = shaftFrame;
    shaftValues.set([x, min.y, z, x, max.y, z]);
    writeSegments(shaft, shaftValues);
    povDot.position.set(x, povY, z);
  }

  function setGripHighlight(grip: Grip | null) {
    for (const f of faces)
      f.handle.material.color.setHex(f === grip ? ACCENT : WHITE);
    povDot.material.color.setHex(grip === "pov" ? ACCENT : WHITE);
    shaft.material.color.setHex(grip === "shaft" ? ACCENT : WHITE);
  }

  function gripAxis(grip: Face | "pov"): Axis {
    return grip === "pov" ? "y" : grip.axis;
  }

  function gripValue(grip: Face | "pov"): number {
    return grip === "pov" ? povY : faceValue(grip);
  }

  function gripCentre(grip: Face | "pov", out: THREE.Vector3): THREE.Vector3 {
    return grip === "pov"
      ? out.set(shaftFrame.x, povY, shaftFrame.z)
      : faceCentre(grip, out);
  }

  const AXIS_VECTORS: Record<RotateAxis, THREE.Vector3> = {
    x: new THREE.Vector3(1, 0, 0),
    y: new THREE.Vector3(0, 1, 0),
    z: new THREE.Vector3(0, 0, 1),
  };

  function ringPoint(axis: RotateAxis, t: number, out: THREE.Vector3) {
    const a = ringRadius * Math.cos(t);
    const b = ringRadius * Math.sin(t);
    if (axis === "x") out.set(0, a, b);
    else if (axis === "y") out.set(a, 0, b);
    else out.set(a, b, 0);
    return out.add(ringCentre);
  }

  function writeRings() {
    const values = new Float32Array(RING_SEGMENTS * 6);
    const from = new THREE.Vector3();
    const to = new THREE.Vector3();
    for (const axis of ["x", "y", "z"] as const) {
      for (let i = 0; i < RING_SEGMENTS; i++) {
        ringPoint(axis, (i / RING_SEGMENTS) * Math.PI * 2, from);
        ringPoint(axis, ((i + 1) / RING_SEGMENTS) * Math.PI * 2, to);
        values.set([from.x, from.y, from.z, to.x, to.y, to.z], i * 6);
      }
      writeSegments(rings[axis], values);
    }
  }

  function writeGrid(floorY: number) {
    const half = ringRadius * GRID_REACH;
    const y = floorY;
    const values = new Float32Array((GRID_DIVISIONS + 1) * 2 * 6);
    let i = 0;
    for (let k = 0; k <= GRID_DIVISIONS; k++) {
      const offset = -half + (2 * half * k) / GRID_DIVISIONS;
      const x = ringCentre.x + offset;
      const z = ringCentre.z + offset;
      values.set([x, y, ringCentre.z - half, x, y, ringCentre.z + half], i);
      values.set([ringCentre.x - half, y, z, ringCentre.x + half, y, z], i + 6);
      i += 12;
    }
    writeSegments(grid, values);
  }

  function setRingHighlight(axis: RotateAxis | null) {
    for (const [key, ring] of Object.entries(rings))
      ring.material.color.setHex(key === axis ? ACCENT : WHITE);
  }

  function applyToolVisibility() {
    for (const part of boxParts) part.visible = tool === "box";
    for (const part of rotateParts) part.visible = tool === "rotate";
  }

  function emphasiseWall(face: Face | null) {
    for (const f of faces)
      f.wall.material.opacity = f === face ? WALL_DRAG_OPACITY : WALL_OPACITY;
  }

  function setPointer(event: PointerEvent) {
    const rect = deps.renderer.domElement.getBoundingClientRect();
    pointer.set(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1,
    );
    raycaster.setFromCamera(pointer, deps.camera);
  }

  function gripUnderPointer(event: PointerEvent): Grip | null {
    setPointer(event);
    const hits = raycaster.intersectObjects(grips, false);
    if (hits.some((h) => h.object === povDot)) return "pov";
    const hit = hits[0];
    if (hit) return faces.find((f) => f.handle === hit.object) ?? null;
    return shaftUnderPointer(event) ? "shaft" : null;
  }

  function shaftUnderPointer(event: PointerEvent): boolean {
    const rect = deps.renderer.domElement.getBoundingClientRect();
    const { x, z, min, max } = shaftFrame;
    const a = new THREE.Vector3(x, min.y, z)
      .applyMatrix4(group.matrix)
      .project(deps.camera);
    const b = new THREE.Vector3(x, max.y, z)
      .applyMatrix4(group.matrix)
      .project(deps.camera);
    if (a.z > 1 || b.z > 1) return false;
    const ax = (a.x * 0.5 + 0.5) * rect.width;
    const ay = (-a.y * 0.5 + 0.5) * rect.height;
    const dx = (b.x * 0.5 + 0.5) * rect.width - ax;
    const dy = (-b.y * 0.5 + 0.5) * rect.height - ay;
    const px = event.clientX - rect.left;
    const py = event.clientY - rect.top;
    const t = Math.max(
      0,
      Math.min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy || 1)),
    );
    return Math.hypot(px - (ax + t * dx), py - (ay + t * dy)) <= SHAFT_HIT_PX;
  }

  function localPointerRay(event: PointerEvent): THREE.Ray | null {
    const model = deps.getModel();
    if (!model) return null;
    setPointer(event);
    inverseModel.copy(model.matrixWorld).invert();
    localRay.copy(raycaster.ray).applyMatrix4(inverseModel);
    return localRay;
  }

  function pointerAlongAxis(
    event: PointerEvent,
    grip: Face | "pov",
  ): number | null {
    const ray = localPointerRay(event);
    if (!ray) return null;
    const point = ray.intersectPlane(dragPlane, scratch);
    if (!point) return null;
    return point[gripAxis(grip)];
  }

  function ringUnderPointer(event: PointerEvent): RotateAxis | null {
    const rect = deps.renderer.domElement.getBoundingClientRect();
    const px = event.clientX - rect.left;
    const py = event.clientY - rect.top;
    const toScreen = (v: THREE.Vector3) => {
      v.applyMatrix4(group.matrix).project(deps.camera);
      return {
        x: (v.x * 0.5 + 0.5) * rect.width,
        y: (-v.y * 0.5 + 0.5) * rect.height,
        behind: v.z > 1,
      };
    };

    let best: RotateAxis | null = null;
    let bestDistance = RING_HIT_PX;
    const point = new THREE.Vector3();
    for (const axis of ["x", "y", "z"] as const) {
      let previous = toScreen(ringPoint(axis, 0, point));
      for (let i = 1; i <= RING_SEGMENTS; i++) {
        const next = toScreen(
          ringPoint(axis, (i / RING_SEGMENTS) * Math.PI * 2, point),
        );
        if (!previous.behind && !next.behind) {
          const dx = next.x - previous.x;
          const dy = next.y - previous.y;
          const lengthSq = dx * dx + dy * dy || 1;
          const t = Math.max(
            0,
            Math.min(
              1,
              ((px - previous.x) * dx + (py - previous.y) * dy) / lengthSq,
            ),
          );
          const distance = Math.hypot(
            px - (previous.x + t * dx),
            py - (previous.y + t * dy),
          );
          if (distance < bestDistance) {
            bestDistance = distance;
            best = axis;
          }
        }
        previous = next;
      }
    }
    return best;
  }

  function pointerAngle(event: PointerEvent, cx: number, cy: number): number {
    const rect = deps.renderer.domElement.getBoundingClientRect();
    return Math.atan2(
      -(event.clientY - rect.top - cy),
      event.clientX - rect.left - cx,
    );
  }

  function beginRotate(axis: RotateAxis, event: PointerEvent): boolean {
    const model = deps.getModel();
    const ray = localPointerRay(event);
    if (!model || !ray) return false;

    const axisVector = AXIS_VECTORS[axis];
    inverseModel.copy(model.matrixWorld).invert();
    deps.camera.getWorldDirection(localViewDir);
    localViewDir.transformDirection(inverseModel);
    const facing = localViewDir.dot(axisVector);

    if (Math.abs(facing) >= FACE_ON_FACING) {
      const rect = deps.renderer.domElement.getBoundingClientRect();
      const centre = ringCentre
        .clone()
        .applyMatrix4(group.matrix)
        .project(deps.camera);
      const centreX = (centre.x * 0.5 + 0.5) * rect.width;
      const centreY = (-centre.y * 0.5 + 0.5) * rect.height;
      rotating = {
        axis,
        method: "circle",
        centreX,
        centreY,
        sign: facing < 0 ? 1 : -1,
        previous: pointerAngle(event, centreX, centreY),
        total: 0,
      };
    } else {
      rotatePlane.setFromNormalAndCoplanarPoint(
        localViewDir.clone().negate(),
        ringCentre,
      );
      const origin = ray.intersectPlane(rotatePlane, new THREE.Vector3());
      if (!origin) return false;
      rotating = {
        axis,
        method: "tangent",
        origin,
        tangent: localViewDir.clone().cross(axisVector).normalize(),
        total: 0,
      };
    }

    setRingHighlight(axis);
    deps.controls.enabled = false;
    return true;
  }

  function moveRotate(event: PointerEvent) {
    if (!rotating) return;

    if (rotating.method === "circle") {
      const angle = pointerAngle(event, rotating.centreX, rotating.centreY);
      let delta = angle - rotating.previous;
      if (delta > Math.PI) delta -= Math.PI * 2;
      else if (delta < -Math.PI) delta += Math.PI * 2;
      rotating.total += rotating.sign * delta;
      rotating.previous = angle;
    } else {
      const ray = localPointerRay(event);
      const hit = ray?.intersectPlane(rotatePlane, new THREE.Vector3());
      if (!hit) return;
      rotating.total =
        hit.sub(rotating.origin).dot(rotating.tangent) / ringRadius;
    }

    const turns = Math.round(rotating.total / SNAP_STEP);
    const snapped =
      turns !== 0 && Math.abs(rotating.total - turns * SNAP_STEP) < SNAP_WITHIN
        ? turns * SNAP_STEP
        : rotating.total;
    deps.onRotate(rotating.axis, snapped);
  }

  function endRotate() {
    if (!rotating) return;
    rotating = null;
    setRingHighlight(hoveredRing);
    deps.controls.enabled = !hoveredRing;
    deps.onRotateEnd();
  }

  function beginShaftDrag(event: PointerEvent): boolean {
    const model = deps.getModel();
    const ray = localPointerRay(event);
    if (!model || !ray) return false;

    const { x, z, min, max } = shaftFrame;
    const grabbed = new THREE.Vector3();
    ray.distanceSqToSegment(
      scratch.set(x, min.y, z),
      new THREE.Vector3(x, max.y, z),
      undefined,
      grabbed,
    );

    inverseModel.copy(model.matrixWorld).invert();
    deps.camera.getWorldDirection(localViewDir);
    localViewDir.transformDirection(inverseModel);
    if (Math.abs(localViewDir.y) >= SHAFT_LEVEL_VIEW) {
      dragPlane.setFromNormalAndCoplanarPoint(AXIS_VECTORS.y, grabbed);
    } else {
      localViewDir.y = 0;
      if (localViewDir.lengthSq() < 1e-8) return false;
      dragPlane.setFromNormalAndCoplanarPoint(
        localViewDir.normalize().negate(),
        grabbed,
      );
    }

    if (!ray.intersectPlane(dragPlane, shaftDragStart)) return false;
    shaftStartX = x;
    shaftStartZ = z;
    dragging = "shaft";
    setGripHighlight("shaft");
    deps.controls.enabled = false;
    return true;
  }

  function moveShaft(event: PointerEvent) {
    const ray = localPointerRay(event);
    const hit = ray?.intersectPlane(dragPlane, scratch);
    if (!hit) return;
    const { min, max } = shaftFrame;
    shaftFrame.x = clampInsideEdges(
      shaftStartX + hit.x - shaftDragStart.x,
      min.x,
      max.x,
    );
    shaftFrame.z = clampInsideEdges(
      shaftStartZ + hit.z - shaftDragStart.z,
      min.z,
      max.z,
    );
    writeShaft();
    deps.onShaftMove(shaftFrame.x, shaftFrame.z);
  }

  function beginDrag(grip: Grip, event: PointerEvent): boolean {
    if (grip === "shaft") return beginShaftDrag(event);
    const model = deps.getModel();
    if (!model) return false;

    localAxis.set(0, 0, 0);
    localAxis[gripAxis(grip)] = 1;

    inverseModel.copy(model.matrixWorld).invert();
    deps.camera.getWorldDirection(localViewDir);
    localViewDir.transformDirection(inverseModel);
    localViewDir.addScaledVector(localAxis, -localViewDir.dot(localAxis));

    if (localViewDir.lengthSq() < 1e-8) return false;
    localViewDir.normalize().negate();

    const centre = gripCentre(grip, new THREE.Vector3());
    dragPlane.setFromNormalAndCoplanarPoint(localViewDir, centre);

    const along = pointerAlongAxis(event, grip);
    if (along == null) return false;

    dragging = grip;
    dragStartAlongAxis = along;
    dragStartValue = gripValue(grip);
    setGripHighlight(grip);
    if (grip !== "pov") emphasiseWall(grip);
    deps.controls.enabled = false;
    return true;
  }

  function moveDrag(event: PointerEvent) {
    if (!dragging) return;
    if (dragging === "shaft") {
      moveShaft(event);
      return;
    }
    const along = pointerAlongAxis(event, dragging);
    if (along == null) return;

    const next = dragStartValue + (along - dragStartAlongAxis);

    if (dragging === "pov") {
      povY = clampPov(next);
      writeShaft();
      deps.onPovChange(povY);
      return;
    }

    const { axis, end } = dragging;
    if (end === "min") {
      box.min[axis] = Math.min(
        Math.max(next, bounds.min[axis]),
        box.max[axis] - MIN_CROP_SIZE,
      );
    } else {
      box.max[axis] = Math.max(
        Math.min(next, bounds.max[axis]),
        box.min[axis] + MIN_CROP_SIZE,
      );
    }

    redraw();
    deps.onChange(box);
  }

  function endDrag() {
    if (!dragging) return;
    const wasFace = dragging !== "pov" && dragging !== "shaft";
    dragging = null;
    emphasiseWall(null);
    setGripHighlight(hovered);
    if (wasFace) deps.onDragEnd();
    deps.controls.enabled = !hovered;
  }

  return {
    show(initial: THREE.Box3, limits: THREE.Box3) {
      bounds.copy(limits);
      box.copy(initial);
      hovered = null;
      dragging = null;
      tool = "box";
      applyToolVisibility();
      setGripHighlight(null);
      emphasiseWall(null);
      redraw();
      group.visible = true;
    },

    hide() {
      endDrag();
      endRotate();
      hovered = null;
      hoveredRing = null;
      setGripHighlight(null);
      group.visible = false;
      deps.controls.enabled = true;
    },

    get visible() {
      return group.visible;
    },

    setTool(
      next: CropGizmoTool,
      rotate?: { centre: THREE.Vector3; size: number; floorY: number },
    ) {
      endDrag();
      endRotate();
      hovered = null;
      hoveredRing = null;
      setGripHighlight(null);
      setRingHighlight(null);
      deps.controls.enabled = true;
      tool = next;
      if (next === "rotate" && rotate) {
        ringCentre.copy(rotate.centre);
        ringRadius = Math.max(rotate.size * RING_RADIUS_FACTOR, MIN_CROP_SIZE);
        writeRings();
        writeGrid(rotate.floorY);
      }
      applyToolVisibility();
    },

    setGridFloor(y: number) {
      if (tool === "rotate") writeGrid(y);
    },

    getBox(): THREE.Box3 {
      return box.clone();
    },

    setBox(next: THREE.Box3) {
      box.copy(next);
      redraw();
      deps.onChange(box);
    },

    setShaft(frame: THREE.Box3, eye: THREE.Vector3): THREE.Vector3 {
      shaftFrame.min.copy(frame.min);
      shaftFrame.max.copy(frame.max);
      shaftFrame.x = clampInsideEdges(eye.x, frame.min.x, frame.max.x);
      shaftFrame.z = clampInsideEdges(eye.z, frame.min.z, frame.max.z);
      povY = clampPov(eye.y);
      writeShaft();
      return new THREE.Vector3(shaftFrame.x, povY, shaftFrame.z);
    },

    onPointerDown(event: PointerEvent): boolean {
      if (!group.visible) return false;
      if (tool === "rotate") {
        const axis = ringUnderPointer(event);
        return axis ? beginRotate(axis, event) : false;
      }
      const grip = gripUnderPointer(event);
      if (!grip) return false;
      return beginDrag(grip, event);
    },

    onPointerMove(event: PointerEvent): boolean {
      if (!group.visible) return false;
      if (tool === "rotate") {
        if (rotating) {
          moveRotate(event);
          return true;
        }
        const axis = ringUnderPointer(event);
        if (axis !== hoveredRing) {
          hoveredRing = axis;
          setRingHighlight(axis);
        }
        deps.controls.enabled = !axis;
        return Boolean(axis);
      }
      if (dragging) {
        moveDrag(event);
        return true;
      }
      const grip = gripUnderPointer(event);
      if (grip !== hovered) {
        hovered = grip;
        setGripHighlight(grip);
      }
      deps.controls.enabled = !grip;
      return Boolean(grip);
    },

    onPointerUp(): boolean {
      const wasDragging = Boolean(dragging) || Boolean(rotating);
      endDrag();
      endRotate();
      return wasDragging;
    },

    update() {
      if (!group.visible) return;
      const model = deps.getModel();
      if (!model) return;

      group.matrix.copy(model.matrixWorld);
      group.matrixWorldNeedsUpdate = true;

      const width = deps.renderer.domElement.clientWidth || 1;
      const height = deps.renderer.domElement.clientHeight || 1;

      const tan = Math.tan((deps.camera.fov * Math.PI) / 360);
      const scale = (HANDLE_HIT_PX * 2 * tan) / height;
      for (const face of faces) face.handle.scale.setScalar(scale);
      povDot.scale.setScalar((POV_HIT_PX * 2 * tan) / height);

      edges.material.resolution.set(width, height);
      brackets.material.resolution.set(width, height);
      shaft.material.resolution.set(width, height);
      for (const ring of Object.values(rings))
        ring.material.resolution.set(width, height);
      grid.material.resolution.set(width, height);
    },

    dispose() {
      deps.scene.remove(group);
      edges.geometry.dispose();
      edges.material.dispose();
      brackets.geometry.dispose();
      brackets.material.dispose();
      wallGeometry.dispose();
      for (const face of faces) face.wall.material.dispose();
      handleTexture.dispose();
      for (const face of faces) face.handle.material.dispose();
      shaft.geometry.dispose();
      shaft.material.dispose();
      povTexture.dispose();
      povDot.material.dispose();
      for (const ring of Object.values(rings)) {
        ring.geometry.dispose();
        ring.material.dispose();
      }
      grid.geometry.dispose();
      grid.material.dispose();
    },
  };
}

export type CropGizmo = ReturnType<typeof createCropGizmo>;

