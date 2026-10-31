import Foundation

public enum CameraMode: String, Codable, Hashable, Sendable {
    case orbit
    case pov
}

public struct CameraSnapshot: Codable, Hashable, Sendable {
    public var cameraMode: CameraMode
    public var cameraFov: Double
    public var modelRotationY: Double
    public var orbitPosX: Double?
    public var orbitPosY: Double?
    public var orbitPosZ: Double?
    public var orbitTargetX: Double?
    public var orbitTargetY: Double?
    public var orbitTargetZ: Double?
    public var rotationX: Double?
    public var rotationY: Double?

    public init(
        cameraMode: CameraMode,
        cameraFov: Double,
        modelRotationY: Double,
        orbitPosX: Double? = nil,
        orbitPosY: Double? = nil,
        orbitPosZ: Double? = nil,
        orbitTargetX: Double? = nil,
        orbitTargetY: Double? = nil,
        orbitTargetZ: Double? = nil,
        rotationX: Double? = nil,
        rotationY: Double? = nil
    ) {
        self.cameraMode = cameraMode
        self.cameraFov = cameraFov
        self.modelRotationY = modelRotationY
        self.orbitPosX = orbitPosX
        self.orbitPosY = orbitPosY
        self.orbitPosZ = orbitPosZ
        self.orbitTargetX = orbitTargetX
        self.orbitTargetY = orbitTargetY
        self.orbitTargetZ = orbitTargetZ
        self.rotationX = rotationX
        self.rotationY = rotationY
    }
}

public struct AnnotationAuthor: Codable, Hashable, Sendable {
    public var id: Int
    public var username: String
    public var displayName: String?
    public var email: String?

    public init(id: Int, username: String, displayName: String? = nil, email: String? = nil) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.email = email
    }

    public var formattedAttribution: String {
        if let displayName, !displayName.isEmpty {
            return displayName
        }
        return "@\(username)"
    }
}

public struct Annotation: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var restroomId: Int
    public var body: String
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
    public var createdAt: String
    public var author: AnnotationAuthor

    public init(
        id: Int,
        restroomId: Int,
        body: String,
        pointX: Double,
        pointY: Double,
        pointZ: Double,
        cameraMode: CameraMode,
        cameraFov: Double,
        orbitPosX: Double? = nil,
        orbitPosY: Double? = nil,
        orbitPosZ: Double? = nil,
        orbitTargetX: Double? = nil,
        orbitTargetY: Double? = nil,
        orbitTargetZ: Double? = nil,
        rotationX: Double? = nil,
        rotationY: Double? = nil,
        modelRotationY: Double? = nil,
        createdAt: String,
        author: AnnotationAuthor
    ) {
        self.id = id
        self.restroomId = restroomId
        self.body = body
        self.pointX = pointX
        self.pointY = pointY
        self.pointZ = pointZ
        self.cameraMode = cameraMode
        self.cameraFov = cameraFov
        self.orbitPosX = orbitPosX
        self.orbitPosY = orbitPosY
        self.orbitPosZ = orbitPosZ
        self.orbitTargetX = orbitTargetX
        self.orbitTargetY = orbitTargetY
        self.orbitTargetZ = orbitTargetZ
        self.rotationX = rotationX
        self.rotationY = rotationY
        self.modelRotationY = modelRotationY
        self.createdAt = createdAt
        self.author = author
    }
}

public struct CreateAnnotationBody: Codable, Hashable, Sendable {
    public var body: String
    public var pointX: Double
    public var pointY: Double
    public var pointZ: Double
    public var cameraMode: CameraMode
    public var cameraFov: Double
    public var modelRotationY: Double
    public var orbitPosX: Double?
    public var orbitPosY: Double?
    public var orbitPosZ: Double?
    public var orbitTargetX: Double?
    public var orbitTargetY: Double?
    public var orbitTargetZ: Double?
    public var rotationX: Double?
    public var rotationY: Double?

    public init(body: String, point: Vec3, snapshot: CameraSnapshot) {
        self.body = body
        self.pointX = point.x
        self.pointY = point.y
        self.pointZ = point.z
        self.cameraMode = snapshot.cameraMode
        self.cameraFov = snapshot.cameraFov
        self.modelRotationY = snapshot.modelRotationY
        self.orbitPosX = snapshot.orbitPosX
        self.orbitPosY = snapshot.orbitPosY
        self.orbitPosZ = snapshot.orbitPosZ
        self.orbitTargetX = snapshot.orbitTargetX
        self.orbitTargetY = snapshot.orbitTargetY
        self.orbitTargetZ = snapshot.orbitTargetZ
        self.rotationX = snapshot.rotationX
        self.rotationY = snapshot.rotationY
    }
}

