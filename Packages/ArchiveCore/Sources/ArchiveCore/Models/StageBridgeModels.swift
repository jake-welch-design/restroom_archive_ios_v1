import Foundation

public struct StageAnnotation: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var number: Int
    public var pointX: Double
    public var pointY: Double
    public var pointZ: Double
    public var cameraMode: CameraMode
    public var cameraFov: Double
    public var orbitPosX: Double?
    public var orbitPosY: Double?
    public var orbitPosZ: Double?
    public var orbitTargetX: Double?
    public var orbitTargetY: Double?
    public var orbitTargetZ: Double?
    public var rotationX: Double?
    public var rotationY: Double?
    public var modelRotationY: Double?

    public init(from annotation: Annotation, number: Int) {
        self.id = annotation.id
        self.number = number
        self.pointX = annotation.pointX
        self.pointY = annotation.pointY
        self.pointZ = annotation.pointZ
        self.cameraMode = annotation.cameraMode
        self.cameraFov = annotation.cameraFov
        self.orbitPosX = annotation.orbitPosX
        self.orbitPosY = annotation.orbitPosY
        self.orbitPosZ = annotation.orbitPosZ
        self.orbitTargetX = annotation.orbitTargetX
        self.orbitTargetY = annotation.orbitTargetY
        self.orbitTargetZ = annotation.orbitTargetZ
        self.rotationX = annotation.rotationX
        self.rotationY = annotation.rotationY
        self.modelRotationY = annotation.modelRotationY
    }
}

public enum StageCommand: Encodable, Sendable {
    case loadScan(
        url: String,
        slug: String?,
        crop: Crop?,
        annotations: [StageAnnotation],
        selectedAnnotationId: Int?
    )
    case clearScan
    case setMode(CameraMode)
    case setAnnotations(annotations: [StageAnnotation], selectedId: Int?)
    case selectAnnotation(id: Int?, fly: Bool)
    case setMarkersVisible(Bool)
    case setCreateMode(Bool)
    case startCrop
    case cancelCrop
    case resetCrop
    case setCropMode(CropMode)
    case setCropTool(CropGizmoTool)
    case confirmCropRound
    case discardCropRound
    case commitCrop
    case applyCommittedCrop(CropResult)

    private enum CodingKeys: String, CodingKey {
        case type
        case url
        case slug
        case crop
        case annotations
        case selectedAnnotationId
        case mode
        case selectedId
        case id
        case fly
        case visible
        case active
        case tool
        case result
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .loadScan(url, slug, crop, annotations, selectedAnnotationId):
            try container.encode("loadScan", forKey: .type)
            try container.encode(url, forKey: .url)
            try container.encode(slug, forKey: .slug)
            try container.encode(crop, forKey: .crop)
            try container.encode(annotations, forKey: .annotations)
            try container.encode(selectedAnnotationId, forKey: .selectedAnnotationId)
        case .clearScan:
            try container.encode("clearScan", forKey: .type)
        case let .setMode(mode):
            try container.encode("setMode", forKey: .type)
            try container.encode(mode, forKey: .mode)
        case let .setAnnotations(annotations, selectedId):
            try container.encode("setAnnotations", forKey: .type)
            try container.encode(annotations, forKey: .annotations)
            try container.encode(selectedId, forKey: .selectedId)
        case let .selectAnnotation(id, fly):
            try container.encode("selectAnnotation", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(fly, forKey: .fly)
        case let .setMarkersVisible(visible):
            try container.encode("setMarkersVisible", forKey: .type)
            try container.encode(visible, forKey: .visible)
        case let .setCreateMode(active):
            try container.encode("setCreateMode", forKey: .type)
            try container.encode(active, forKey: .active)
        case .startCrop:
            try container.encode("startCrop", forKey: .type)
        case .cancelCrop:
            try container.encode("cancelCrop", forKey: .type)
        case .resetCrop:
            try container.encode("resetCrop", forKey: .type)
        case let .setCropMode(mode):
            try container.encode("setCropMode", forKey: .type)
            try container.encode(mode, forKey: .mode)
        case let .setCropTool(tool):
            try container.encode("setCropTool", forKey: .type)
            try container.encode(tool, forKey: .tool)
        case .confirmCropRound:
            try container.encode("confirmCropRound", forKey: .type)
        case .discardCropRound:
            try container.encode("discardCropRound", forKey: .type)
        case .commitCrop:
            try container.encode("commitCrop", forKey: .type)
        case let .applyCommittedCrop(result):
            try container.encode("applyCommittedCrop", forKey: .type)
            try container.encode(result, forKey: .result)
        }
    }
}

public struct StageCropStatePayload: Codable, Hashable, Sendable {
    public var editing: Bool
    public var ready: Bool
    public var tool: CropGizmoTool
    public var mode: CropMode
    public var hasChanges: Bool
    public var roundPending: Bool
    public var emptiesScan: Bool
    public var rotateDegrees: Double?
    public var strandedCount: Int
    public var boxResetNotice: Bool?

    public static let idle = StageCropStatePayload(
        editing: false,
        ready: false,
        tool: .box,
        mode: .keep,
        hasChanges: false,
        roundPending: false,
        emptiesScan: false,
        rotateDegrees: nil,
        strandedCount: 0,
        boxResetNotice: nil
    )
}

public enum StageEvent: Decodable, Hashable, Sendable {
    case ready
    case scanLoading(slug: String?)
    case scanLoaded(slug: String?)
    case scanError(message: String, rateLimited: Bool)
    case modeChanged(CameraMode)
    case annotationTapped(id: Int)
    case pointPicked(point: Vec3, snapshot: CameraSnapshot)
    case cropState(StageCropStatePayload)
    case cropResult(result: CropResult?, thumbDataUrl: String?)

    private enum CodingKeys: String, CodingKey {
        case type
        case slug
        case message
        case rateLimited
        case mode
        case id
        case point
        case snapshot
        case result
        case thumbDataUrl
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "ready":
            self = .ready
        case "scanLoading":
            self = .scanLoading(slug: try container.decodeIfPresent(String.self, forKey: .slug))
        case "scanLoaded":
            self = .scanLoaded(slug: try container.decodeIfPresent(String.self, forKey: .slug))
        case "scanError":
            self = .scanError(
                message: try container.decode(String.self, forKey: .message),
                rateLimited: try container.decodeIfPresent(Bool.self, forKey: .rateLimited) ?? false
            )
        case "modeChanged":
            self = .modeChanged(try container.decode(CameraMode.self, forKey: .mode))
        case "annotationTapped":
            self = .annotationTapped(id: try container.decode(Int.self, forKey: .id))
        case "pointPicked":
            self = .pointPicked(
                point: try container.decode(Vec3.self, forKey: .point),
                snapshot: try container.decode(CameraSnapshot.self, forKey: .snapshot)
            )
        case "cropState":
            let payload = try StageCropStatePayload(from: decoder)
            self = .cropState(payload)
        case "cropResult":
            self = .cropResult(
                result: try container.decodeIfPresent(CropResult.self, forKey: .result),
                thumbDataUrl: try container.decodeIfPresent(String.self, forKey: .thumbDataUrl)
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown StageEvent type: \(type)"
            )
        }
    }
}

