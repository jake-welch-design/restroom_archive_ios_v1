export interface Vec3 {
  x: number;
  y: number;
  z: number;
}

/** A unit quaternion. */
export interface Quat {
  x: number;
  y: number;
  z: number;
  w: number;
}

export interface Level {
  rotation: Quat;
  pivot: Vec3;
}

export const IDENTITY_QUAT: Quat = { x: 0, y: 0, z: 0, w: 1 };
const ORIGIN: Vec3 = { x: 0, y: 0, z: 0 };

export function quatMultiply(a: Quat, b: Quat): Quat {
  return {
    x: a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
    y: a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
    z: a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
    w: a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
  };
}

export function quatConjugate(q: Quat): Quat {
  return { x: -q.x, y: -q.y, z: -q.z, w: q.w };
}

export function quatNormalize(q: Quat): Quat {
  const length = Math.hypot(q.x, q.y, q.z, q.w) || 1;
  return { x: q.x / length, y: q.y / length, z: q.z / length, w: q.w / length };
}

export function quatAboutY(angle: number): Quat {
  return { x: 0, y: Math.sin(angle / 2), z: 0, w: Math.cos(angle / 2) };
}

export function rotate(q: Quat, v: Vec3): Vec3 {
  const cx = q.y * v.z - q.z * v.y;
  const cy = q.z * v.x - q.x * v.z;
  const cz = q.x * v.y - q.y * v.x;
  return {
    x: v.x + 2 * (q.w * cx + q.y * cz - q.z * cy),
    y: v.y + 2 * (q.w * cy + q.z * cx - q.x * cz),
    z: v.z + 2 * (q.w * cz + q.x * cy - q.y * cx),
  };
}

const add = (a: Vec3, b: Vec3): Vec3 => ({
  x: a.x + b.x,
  y: a.y + b.y,
  z: a.z + b.z,
});
const sub = (a: Vec3, b: Vec3): Vec3 => ({
  x: a.x - b.x,
  y: a.y - b.y,
  z: a.z - b.z,
});

export function isLevelled(level: Level | null | undefined): level is Level {
  if (!level) return false;
  const angle = 2 * Math.acos(Math.min(1, Math.abs(level.rotation.w)));
  return angle > (0.01 * Math.PI) / 180;
}

export function povDirection(pitch: number, yaw: number): Vec3 {
  return {
    x: -Math.sin(yaw) * Math.cos(pitch),
    y: Math.sin(pitch),
    z: -Math.cos(yaw) * Math.cos(pitch),
  };
}

export function povAngles(d: Vec3): { pitch: number; yaw: number } {
  const length = Math.hypot(d.x, d.y, d.z) || 1;
  return {
    pitch: Math.asin(Math.max(-1, Math.min(1, d.y / length))),
    yaw: Math.atan2(-d.x, -d.z),
  };
}

export interface Framing {
  level: Level | null;
  centre: Vec3;
}

export interface AnnotationPlacement {
  pointX: number;
  pointY: number;
  pointZ: number;
  cameraMode: string;
  orbitPosX: number | null;
  orbitPosY: number | null;
  orbitPosZ: number | null;
  orbitTargetX: number | null;
  orbitTargetY: number | null;
  orbitTargetZ: number | null;
  rotationX: number | null;
  rotationY: number | null;
  modelRotationY: number | null;
}

export function reframeAnnotation(
  a: AnnotationPlacement,
  before: Framing,
  after: Framing,
): AnnotationPlacement {
  const rBefore = before.level?.rotation ?? IDENTITY_QUAT;
  const rAfter = after.level?.rotation ?? IDENTITY_QUAT;
  const pivot = after.level?.pivot ?? before.level?.pivot ?? ORIGIN;

  const n = quatNormalize(quatMultiply(rAfter, quatConjugate(rBefore)));
  const turn = quatAboutY(a.modelRotationY ?? 0);
  const m = quatMultiply(quatMultiply(turn, n), quatConjugate(turn));
  const shift = sub(rotate(turn, sub(pivot, rotate(n, pivot))), after.centre);

  const point = add(
    rotate(n, sub({ x: a.pointX, y: a.pointY, z: a.pointZ }, pivot)),
    pivot,
  );
  const carry = (v: Vec3) => add(rotate(m, add(v, before.centre)), shift);

  const next: AnnotationPlacement = {
    ...a,
    pointX: point.x,
    pointY: point.y,
    pointZ: point.z,
  };

  if (a.orbitPosX != null && a.orbitPosY != null && a.orbitPosZ != null) {
    const pos = carry({ x: a.orbitPosX, y: a.orbitPosY, z: a.orbitPosZ });
    next.orbitPosX = pos.x;
    next.orbitPosY = pos.y;
    next.orbitPosZ = pos.z;
  }
  if (
    a.orbitTargetX != null &&
    a.orbitTargetY != null &&
    a.orbitTargetZ != null
  ) {
    const target = carry({
      x: a.orbitTargetX,
      y: a.orbitTargetY,
      z: a.orbitTargetZ,
    });
    next.orbitTargetX = target.x;
    next.orbitTargetY = target.y;
    next.orbitTargetZ = target.z;
  }
  if (a.cameraMode === "pov" && a.rotationX != null && a.rotationY != null) {
    const { pitch, yaw } = povAngles(
      rotate(m, povDirection(a.rotationX, a.rotationY)),
    );
    next.rotationX = pitch;
    next.rotationY = yaw;
  }

  return next;
}

