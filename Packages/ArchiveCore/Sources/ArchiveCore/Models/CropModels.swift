import Foundation

public struct Vec3: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = Vec3(x: 0, y: 0, z: 0)
}

public struct Quat: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double
    public var w: Double

    public init(x: Double, y: Double, z: Double, w: Double) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    public static let identity = Quat(x: 0, y: 0, z: 0, w: 1)

    public var normalized: Quat {
        let len = (x * x + y * y + z * z + w * w).squareRoot()
        guard len > 0 else { return .identity }
        return Quat(x: x / len, y: y / len, z: z / len, w: w / len)
    }
}

public struct Level: Codable, Hashable, Sendable {
    public var rotation: Quat
    public var pivot: Vec3

    public init(rotation: Quat, pivot: Vec3) {
        self.rotation = rotation
        self.pivot = pivot
    }

    public var isLevelled: Bool {
        let clampedW = min(1.0, abs(rotation.w))
        let angle = 2.0 * acos(clampedW)
        return angle > (0.01 * .pi) / 180.0
    }
}

public struct CropBox: Codable, Hashable, Sendable {
    public var minX: Double
    public var minY: Double
    public var minZ: Double
    public var maxX: Double
    public var maxY: Double
    public var maxZ: Double

    public init(
        minX: Double,
        minY: Double,
        minZ: Double,
        maxX: Double,
        maxY: Double,
        maxZ: Double
    ) {
        self.minX = minX
        self.minY = minY
        self.minZ = minZ
        self.maxX = maxX
        self.maxY = maxY
        self.maxZ = maxZ
    }

    public func contains(_ point: Vec3) -> Bool {
        point.x >= minX && point.x <= maxX &&
        point.y >= minY && point.y <= maxY &&
        point.z >= minZ && point.z <= maxZ
    }
}

public enum CropMode: String, Codable, Hashable, Sendable {
    case keep
    case remove
}

public enum CropGizmoTool: String, Codable, Hashable, Sendable {
    case box
    case rotate
}

public struct Crop: Codable, Hashable, Sendable {
    public static let minCropSize: Double = 0.05
    public static let maxCropRemovals: Int = 32

    public var mode: CropMode
    public var box: CropBox
    public var frame: CropBox
    public var removed: [CropBox]?
    public var povY: Double?
    public var povX: Double?
    public var povZ: Double?
    public var level: Level?

    public init(
        mode: CropMode,
        box: CropBox,
        frame: CropBox,
        removed: [CropBox]? = nil,
        povY: Double? = nil,
        povX: Double? = nil,
        povZ: Double? = nil,
        level: Level? = nil
    ) {
        self.mode = mode
        self.box = box
        self.frame = frame
        self.removed = removed
        self.povY = povY
        self.povX = povX
        self.povZ = povZ
        self.level = level
    }
}

public struct CropResult: Codable, Hashable, Sendable {
    public var crop: Crop?
    public var centreBefore: Vec3
    public var centreAfter: Vec3

    public init(crop: Crop?, centreBefore: Vec3, centreAfter: Vec3) {
        self.crop = crop
        self.centreBefore = centreBefore
        self.centreAfter = centreAfter
    }
}

