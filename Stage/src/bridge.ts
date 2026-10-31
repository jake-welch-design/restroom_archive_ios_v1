import type { Crop, CropMode } from "./shared/crop";
import type { CropGizmoTool } from "./shared/cropGizmo";
import type { Vec3 } from "./shared/levelling";

export type CameraMode = "orbit" | "pov";

export interface CameraSnapshot {
  cameraMode: CameraMode;
  cameraFov: number;
  modelRotationY: number;
  orbitPosX?: number;
  orbitPosY?: number;
  orbitPosZ?: number;
  orbitTargetX?: number;
  orbitTargetY?: number;
  orbitTargetZ?: number;
  rotationX?: number;
  rotationY?: number;
}

export interface StageAnnotation {
  id: number;
  number: number;
  pointX: number;
  pointY: number;
  pointZ: number;
  cameraMode: CameraMode;
  cameraFov: number;
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

export interface CropResult {
  crop: Crop | null;
  centreBefore: Vec3;
  centreAfter: Vec3;
}

export type StageCommand =
  | {
      type: "loadScan";
      url: string;
      slug: string | null;
      crop: Crop | null;
      annotations: StageAnnotation[];
      selectedAnnotationId?: number | null;
    }
  | { type: "clearScan" }
  | { type: "setMode"; mode: CameraMode }
  | {
      type: "setAnnotations";
      annotations: StageAnnotation[];
      selectedId: number | null;
    }
  | { type: "selectAnnotation"; id: number | null; fly: boolean }
  | { type: "setMarkersVisible"; visible: boolean }
  | { type: "setCreateMode"; active: boolean }
  | { type: "startCrop" }
  | { type: "cancelCrop" }
  | { type: "resetCrop" }
  | { type: "setCropMode"; mode: CropMode }
  | { type: "setCropTool"; tool: CropGizmoTool }
  | { type: "confirmCropRound" }
  | { type: "discardCropRound" }
  | { type: "commitCrop" }
  | { type: "applyCommittedCrop"; result: CropResult };

export type StageEvent =
  | { type: "ready" }
  | { type: "scanLoading"; slug: string | null }
  | { type: "scanLoaded"; slug: string | null }
  | { type: "scanError"; message: string; rateLimited: boolean }
  | { type: "modeChanged"; mode: CameraMode }
  | { type: "annotationTapped"; id: number }
  | { type: "pointPicked"; point: Vec3; snapshot: CameraSnapshot }
  | {
      type: "cropState";
      editing: boolean;
      ready: boolean;
      tool: CropGizmoTool;
      mode: CropMode;
      hasChanges: boolean;
      roundPending: boolean;
      emptiesScan: boolean;
      rotateDegrees: number | null;
      strandedCount: number;
      boxResetNotice?: boolean;
    }
  | {
      type: "cropResult";
      result: CropResult | null;
      thumbDataUrl: string | null;
    };

declare global {
  interface Window {
    webkit?: {
      messageHandlers?: {
        archiveStage?: {
          postMessage(payload: StageEvent): void;
        };
      };
    };
    ArchiveStage?: {
      dispatch(command: StageCommand | string): void;
    };
  }
}

export function postStageEvent(event: StageEvent): void {
  try {
    window.webkit?.messageHandlers?.archiveStage?.postMessage(event);
  } catch (err) {
    console.error("[ArchiveStage] Failed to post event:", err);
  }
}

