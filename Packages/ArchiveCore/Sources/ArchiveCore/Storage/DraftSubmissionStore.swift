import Foundation

public struct DraftSubmission: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var glbFileName: String
    public var glbRelativePath: String
    public var glbByteSize: Int64
    public var name: String
    public var city: String
    public var country: String
    public var subdivision: String
    public var isoDate: String
    public var lat: String
    public var lng: String
    public var description: String
    public var descriptors: [String]
    public var sourceNote: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        glbFileName: String,
        glbRelativePath: String,
        glbByteSize: Int64,
        name: String = "",
        city: String = "",
        country: String = "",
        subdivision: String = "",
        isoDate: String = ArchiveDateFormatter.isoDateString(from: Date()),
        lat: String = "",
        lng: String = "",
        description: String = "",
        descriptors: [String] = [],
        sourceNote: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.glbFileName = glbFileName
        self.glbRelativePath = glbRelativePath
        self.glbByteSize = glbByteSize
        self.name = name
        self.city = city
        self.country = country
        self.subdivision = subdivision
        self.isoDate = isoDate
        self.lat = lat
        self.lng = lng
        self.description = description
        self.descriptors = descriptors
        self.sourceNote = sourceNote
    }
}

public actor DraftSubmissionStore {
    public static let appGroupIdentifier = "group.com.restroomarchive.shared"

    public let rootDirectory: URL
    private let indexURL: URL

    public init(customRootDirectory: URL? = nil) {
        let base: URL
        if let customRootDirectory {
            base = customRootDirectory
        } else if let groupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) {
            base = groupContainer.appendingPathComponent("DraftSubmissions", isDirectory: true)
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            base = support.appendingPathComponent("RestroomArchiveDrafts", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.rootDirectory = base
        self.indexURL = base.appendingPathComponent("drafts.json")
    }

    public func listDrafts() -> [DraftSubmission] {
        guard let data = try? Data(contentsOf: indexURL),
              let drafts = try? JSONDecoder().decode([DraftSubmission].self, from: data) else {
            return []
        }
        return drafts.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func draft(id: UUID) -> DraftSubmission? {
        listDrafts().first(where: { $0.id == id })
    }

    public func glbData(for draft: DraftSubmission) -> Data? {
        let url = rootDirectory.appendingPathComponent(draft.glbRelativePath)
        return try? Data(contentsOf: url)
    }

    public func glbFileURL(for draft: DraftSubmission) -> URL {
        rootDirectory.appendingPathComponent(draft.glbRelativePath)
    }

    @discardableResult
    public func createDraftFromGLB(
        data: Data,
        originalFileName: String,
        sourceNote: String? = nil,
        lat: String = "",
        lng: String = "",
        city: String = "",
        country: String = "",
        subdivision: String = "",
        name: String = ""
    ) throws -> DraftSubmission {
        let byteCount = Int64(data.count)
        if byteCount > UploadLimits.maxGlbBytes {
            throw ArchiveAPIError.fileTooLarge(byteCount)
        }
        if !UploadLimits.hasValidGLBMagic(data) {
            throw ArchiveAPIError.invalidGLBFile
        }

        let id = UUID()
        let relativeName = "\(id.uuidString).glb"
        let destURL = rootDirectory.appendingPathComponent(relativeName)
        try data.write(to: destURL, options: .atomic)

        let draft = DraftSubmission(
            id: id,
            glbFileName: originalFileName.isEmpty ? "scan.glb" : originalFileName,
            glbRelativePath: relativeName,
            glbByteSize: byteCount,
            name: name,
            city: city,
            country: country,
            subdivision: subdivision,
            lat: lat,
            lng: lng,
            sourceNote: sourceNote
        )

        var all = listDrafts()
        all.insert(draft, at: 0)
        try persist(all)
        return draft
    }

    public func updateDraft(_ updated: DraftSubmission) throws {
        var all = listDrafts()
        var copy = updated
        copy.updatedAt = Date()
        if let idx = all.firstIndex(where: { $0.id == copy.id }) {
            all[idx] = copy
        } else {
            all.insert(copy, at: 0)
        }
        try persist(all)
    }

    public func deleteDraft(id: UUID) throws {
        var all = listDrafts()
        if let removed = all.first(where: { $0.id == id }) {
            let fileURL = rootDirectory.appendingPathComponent(removed.glbRelativePath)
            try? FileManager.default.removeItem(at: fileURL)
        }
        all.removeAll(where: { $0.id == id })
        try persist(all)
    }

    private func persist(_ drafts: [DraftSubmission]) throws {
        let data = try JSONEncoder().encode(drafts)
        try data.write(to: indexURL, options: .atomic)
    }
}

