#if canImport(SwiftUI) && canImport(UIKit)
import ArchiveCore
import SwiftUI
import UIKit

public struct AsyncCachedImage<Placeholder: View>: View {
    let remotePath: String?
    let apiClient: APIClient
    let diskCache: DiskAssetCache
    let contentMode: ContentMode
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?
    @State private var didFail = false

    public init(
        remotePath: String?,
        apiClient: APIClient,
        diskCache: DiskAssetCache,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.remotePath = remotePath
        self.apiClient = apiClient
        self.diskCache = diskCache
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    public var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: remotePath) {
            await load()
        }
    }

    private func load() async {
        uiImage = nil
        didFail = false
        guard let remotePath, !remotePath.isEmpty else { return }

        if let cached = await diskCache.cachedData(for: remotePath),
           let decoded = UIImage(data: cached) {
            uiImage = decoded
            return
        }

        do {
            let client = apiClient
            let data = try await diskCache.fetchOrLoad(remotePath: remotePath) {
                let (bytes, _) = try await client.downloadRawData(from: remotePath)
                return bytes
            }
            if !Task.isCancelled, let decoded = UIImage(data: data) {
                uiImage = decoded
            } else {
                didFail = true
            }
        } catch {
            if !Task.isCancelled {
                didFail = true
            }
        }
    }
}
#endif

