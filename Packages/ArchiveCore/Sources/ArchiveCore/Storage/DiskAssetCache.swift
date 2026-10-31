import CryptoKit
import Foundation

public actor DiskAssetCache {
    private let rootDirectory: URL
    private let maxBytes: Int64
    private var inFlight: [String: Task<Data, Error>] = [:]

    public init(directoryName: String = "ArchiveModelCache", maxBytes: Int64 = 500 * 1_000_000) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = caches.appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.rootDirectory = dir
        self.maxBytes = maxBytes
    }

    public func cachedData(for remotePath: String) -> Data? {
        let fileURL = localFileURL(for: remotePath)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: fileURL.path
        )
        return data
    }

    public func fetchOrLoad(
        remotePath: String,
        loader: @Sendable @escaping () async throws -> Data
    ) async throws -> Data {
        if let hit = cachedData(for: remotePath) {
            return hit
        }
        if let active = inFlight[remotePath] {
            return try await active.value
        }

        let task = Task<Data, Error> {
            let data = try await loader()
            return data
        }
        inFlight[remotePath] = task

        do {
            let data = try await task.value
            inFlight[remotePath] = nil
            store(data: data, for: remotePath)
            return data
        } catch {
            inFlight[remotePath] = nil
            throw error
        }
    }

    public func store(data: Data, for remotePath: String) {
        let fileURL = localFileURL(for: remotePath)
        try? data.write(to: fileURL, options: .atomic)
        trimIfNeeded()
    }

    public func saveCatalogSnapshot(_ rows: [RestroomSummary]) {
        let snapURL = rootDirectory.appendingPathComponent("catalog_snapshot.json")
        if let data = try? JSONEncoder().encode(rows) {
            try? data.write(to: snapURL, options: .atomic)
        }
    }

    public func loadCatalogSnapshot() -> [RestroomSummary]? {
        let snapURL = rootDirectory.appendingPathComponent("catalog_snapshot.json")
        guard let data = try? Data(contentsOf: snapURL) else { return nil }
        return try? JSONDecoder().decode([RestroomSummary].self, from: data)
    }

    public func clearAll() {
        try? FileManager.default.removeItem(at: rootDirectory)
        try? FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    private func localFileURL(for remotePath: String) -> URL {
        let digest = SHA256.hash(data: Data(remotePath.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let ext = (remotePath as NSString).pathExtension
        let safeExt = ext.isEmpty ? "bin" : String(ext.split(separator: "?").first ?? "bin")
        return rootDirectory.appendingPathComponent("\(hex).\(safeExt)")
    }

    private func trimIfNeeded() {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        struct Entry {
            let url: URL
            let size: Int64
            let modified: Date
        }

        var entries: [Entry] = []
        var total: Int64 = 0
        for url in urls where url.lastPathComponent != "catalog_snapshot.json" {
            let vals = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let sz = Int64(vals?.fileSize ?? 0)
            let mod = vals?.contentModificationDate ?? .distantPast
            entries.append(Entry(url: url, size: sz, modified: mod))
            total += sz
        }

        guard total > maxBytes else { return }
        entries.sort { $0.modified < $1.modified }
        for entry in entries {
            try? fm.removeItem(at: entry.url)
            total -= entry.size
            if total <= maxBytes * 8 / 10 {
                break
            }
        }
    }
}

