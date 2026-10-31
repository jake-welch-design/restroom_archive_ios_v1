import { isLevelled, quatNormalize, type Level } from "./levelling";

export interface CropBox {
  minX: number;
  minY: number;
  minZ: number;
  maxX: number;
  maxY: number;
  maxZ: number;
}

export type CropMode = "keep" | "remove";

export interface Crop {
  mode: CropMode;
  box: CropBox;
  frame: CropBox;
  removed?: CropBox[];
  povY?: number;
  povX?: number;
  povZ?: number;
  level?: Level;
}

export const MIN_CROP_SIZE = 0.05;
export const MAX_CROP_REMOVALS = 32;

const AXES = ["minX", "minY", "minZ", "maxX", "maxY", "maxZ"] as const;

function isBox(value: unknown): value is CropBox {
  if (!value || typeof value !== "object") return false;
  const box = value as Record<string, unknown>;
  return AXES.every(
    (k) => typeof box[k] === "number" && Number.isFinite(box[k]),
  );
}

const finite = (v: unknown): v is number =>
  typeof v === "number" && Number.isFinite(v);

function parseLevel(value: unknown): Level | undefined {
  if (!value || typeof value !== "object") return undefined;
  const { rotation, pivot } = value as Record<string, Record<string, unknown>>;
  if (
    !rotation ||
    !pivot ||
    ![rotation.x, rotation.y, rotation.z, rotation.w].every(finite) ||
    ![pivot.x, pivot.y, pivot.z].every(finite)
  )
    return undefined;
  const level: Level = {
    rotation: quatNormalize(rotation as unknown as Level["rotation"]),
    pivot: pivot as unknown as Level["pivot"],
  };
  return isLevelled(level) ? level : undefined;
}

export function parseCrop(value: string | null | undefined): Crop | null {
  if (!value) return null;
  try {
    const parsed = JSON.parse(value) as Record<string, unknown>;
    const mode = parsed.mode === "remove" ? "remove" : "keep";
    if (!isBox(parsed.box)) return null;
    const frame = isBox(parsed.frame) ? parsed.frame : parsed.box;
    const povY =
      typeof parsed.povY === "number" && Number.isFinite(parsed.povY)
        ? parsed.povY
        : undefined;
    const povXZ =
      finite(parsed.povX) && finite(parsed.povZ)
        ? { povX: parsed.povX, povZ: parsed.povZ }
        : {};
    const level = parseLevel(parsed.level);
    const removed = Array.isArray(parsed.removed)
      ? parsed.removed.filter(isBox)
      : [];
    return {
      mode,
      box: parsed.box,
      frame,
      ...(removed.length ? { removed } : {}),
      ...(povY == null ? {} : { povY }),
      ...povXZ,
      ...(level ? { level } : {}),
    };
  } catch {
    return null;
  }
}

