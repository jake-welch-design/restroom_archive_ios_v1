import Foundation

public struct SessionUser: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var email: String
    public var username: String
    public var displayName: String?
    public var role: String
    public var submissionRequestedAt: String?
    public var approvedAt: String?
    public var mutedUntil: String?
    public var bannedAt: String?
    public var adminMessage: String?
    public var adminMessageAt: String?

    public init(
        id: Int,
        email: String,
        username: String,
        displayName: String? = nil,
        role: String = "archivist",
        submissionRequestedAt: String? = nil,
        approvedAt: String? = nil,
        mutedUntil: String? = nil,
        bannedAt: String? = nil,
        adminMessage: String? = nil,
        adminMessageAt: String? = nil
    ) {
        self.id = id
        self.email = email
        self.username = username
        self.displayName = displayName
        self.role = role
        self.submissionRequestedAt = submissionRequestedAt
        self.approvedAt = approvedAt
        self.mutedUntil = mutedUntil
        self.bannedAt = bannedAt
        self.adminMessage = adminMessage
        self.adminMessageAt = adminMessageAt
    }

    public var isAdmin: Bool {
        role == "admin"
    }

    public var canSubmit: Bool {
        isAdmin || approvedAt != nil
    }

    public var submissionRequested: Bool {
        !canSubmit && submissionRequestedAt != nil
    }

    public var isMuted: Bool {
        ArchiveDateFormatter.isFuture(mutedUntil)
    }

    public var isBanned: Bool {
        bannedAt != nil
    }

    public var formattedAttribution: String {
        if let displayName, !displayName.isEmpty {
            return displayName
        }
        return "@\(username)"
    }
}

public struct MobileAuthResponse: Codable, Hashable, Sendable {
    public var ok: Bool
    public var token: String
    public var expiresAt: String
    public var user: SessionUser
}

public struct SessionResponse: Codable, Hashable, Sendable {
    public var user: SessionUser?
}

public struct BlockedUser: Codable, Identifiable, Hashable, Sendable {
    public var id: String { username }
    public var username: String
    public var displayName: String?
    public var createdAt: String

    public init(username: String, displayName: String? = nil, createdAt: String) {
        self.username = username
        self.displayName = displayName
        self.createdAt = createdAt
    }
}

public struct NotifySettings: Codable, Hashable, Sendable {
    public var enabled: Bool
    public var connected: Bool
    public var telegramName: String?
    public var serverConfigured: Bool
}

public struct TelegramLink: Codable, Hashable, Sendable {
    public var code: String
    public var botUsername: String
    public var url: String
    public var expiresInMinutes: Int
}

public struct AdminUserRef: Codable, Hashable, Sendable {
    public var username: String
    public var displayName: String?

    public var formattedAttribution: String {
        if let displayName, !displayName.isEmpty {
            return displayName
        }
        return "@\(username)"
    }
}

public struct AdminUserContact: Codable, Hashable, Sendable {
    public var username: String
    public var displayName: String?
    public var email: String

    public var formattedAttribution: String {
        if let displayName, !displayName.isEmpty {
            return displayName
        }
        return "@\(username)"
    }
}

public struct MySubmission: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var slug: String
    public var name: String
    public var location: String
    public var date: String
    public var isoDate: String
    public var status: String
    public var createdAt: String
    public var removalRequested: Bool
    public var removalMessage: String?
    public var rejectionMessage: String?

    public var statusDisplayLabel: String {
        if status == "removed" {
            return removalRequested ? "Removed at your request" : "Removed by an admin"
        }
        switch status {
        case "published": return "Published"
        case "pending": return "Awaiting review"
        case "rejected", "hidden": return "Rejected"
        default: return status
        }
    }

    public var adminNote: String? {
        if status == "removed" { return removalMessage }
        if status == "rejected" { return rejectionMessage }
        return nil
    }
}

public struct MyAnnotation: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var body: String
    public var createdAt: String
    public var restroomSlug: String
    public var restroomName: String
    public var restroomLocation: String
    public var restroomDate: String
}

public struct PendingRestroom: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var slug: String
    public var name: String
    public var location: String
    public var date: String
    public var isoDate: String
    public var lat: Double?
    public var lng: Double?
    public var description: String?
    public var descriptors: [String]
    public var crop: Crop?
    public var modelUrl: String
    public var createdAt: String
    public var submitter: AdminUserContact?
}

public struct PendingUser: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var email: String
    public var username: String
    public var displayName: String?
    public var createdAt: String
    public var submissionRequestedAt: String?
}

public struct RemovalRequest: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var slug: String
    public var name: String
    public var location: String
    public var date: String
    public var status: String
    public var removalReason: String?
    public var requester: AdminUserContact?
}

public struct AnnotationReportItem: Codable, Identifiable, Hashable, Sendable {
    public struct AnnotationSnippet: Codable, Hashable, Sendable {
        public var id: Int
        public var body: String
        public var createdAt: String
        public var hiddenAt: String?
    }

    public struct RestroomSnippet: Codable, Hashable, Sendable {
        public var slug: String
        public var name: String
    }

    public var id: Int { reportId }
    public var reportId: Int
    public var reportReason: String?
    public var reportCreatedAt: String
    public var annotation: AnnotationSnippet
    public var restroom: RestroomSnippet
    public var reporter: AdminUserRef?
    public var author: AdminUserRef?
}

public struct AdminAnnotation: Codable, Identifiable, Hashable, Sendable {
    public struct RestroomSnippet: Codable, Hashable, Sendable {
        public var slug: String
        public var name: String
        public var location: String
        public var date: String
    }

    public var id: Int
    public var body: String
    public var createdAt: String
    public var hiddenAt: String?
    public var openReportCount: Int
    public var restroom: RestroomSnippet
    public var author: AdminUserRef?
}

public struct ArchiveEntry: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var slug: String
    public var name: String
    public var location: String
    public var date: String
    public var isoDate: String
    public var status: String
    public var removalMessage: String?
    public var removalRequested: Bool
    public var createdAt: String
    public var submitter: AdminUserRef?
}

public struct RejectedSubmission: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var slug: String
    public var name: String
    public var location: String
    public var date: String
    public var isoDate: String
    public var rejectionMessage: String?
    public var rejectedAt: String?
    public var scanPurgedAt: String?
    public var restorable: Bool
    public var createdAt: String
    public var submitter: AdminUserRef?
}

public struct AccountRow: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var email: String
    public var username: String
    public var displayName: String?
    public var role: String
    public var submissionRequestedAt: String?
    public var approvedAt: String?
    public var mutedUntil: String?
    public var bannedAt: String?
    public var adminMessage: String?
    public var adminMessageAt: String?
    public var createdAt: String
    public var submissionCount: Int
    public var annotationCount: Int

    public var accountTypeLabel: String {
        if role == "admin" { return "Admin" }
        if approvedAt != nil { return "Archivist" }
        return "Annotator"
    }

    public var isMuted: Bool {
        ArchiveDateFormatter.isFuture(mutedUntil)
    }
}

public struct AccountSubmission: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var slug: String
    public var name: String
    public var location: String
    public var date: String
    public var status: String
}

public struct AccountAnnotation: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var body: String
    public var createdAt: String
    public var hiddenAt: String?
    public var restroomSlug: String
    public var restroomName: String
}

public enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let obj = try? container.decode([String: JSONValue].self) {
            self = .object(obj)
        } else if let arr = try? container.decode([JSONValue].self) {
            self = .array(arr)
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }

    public var compactSummary: String {
        switch self {
        case .string(let s): return s
        case .number(let n):
            return n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        case .array(let arr):
            return "[" + arr.map(\.compactSummary).joined(separator: ", ") + "]"
        case .object(let dict):
            return dict.keys.sorted().map { "\($0): \(dict[$0]?.compactSummary ?? "")" }.joined(separator: " · ")
        }
    }
}

public struct AuditLogEntry: Codable, Identifiable, Hashable, Sendable {
    public struct ActorRef: Codable, Hashable, Sendable {
        public var id: Int
        public var username: String
        public var displayName: String?
    }

    public var id: Int
    public var action: String
    public var targetType: String
    public var targetId: Int?
    public var metadata: [String: JSONValue]?
    public var createdAt: String
    public var actor: ActorRef?
}

