#if canImport(WebKit)
import ArchiveCore
import Foundation
import WebKit

/// Serves the bundled Three.js stage (`archive-stage://app/*`), cached remote `.glb`
/// models (`archive-stage://models/*`), and local submission preview `.glb` files
/// (`archive-stage://preview/*`) directly into `WKWebView` with zero CORS preflight.
public final class ArchiveSchemeHandler: NSObject, WKURLSchemeHandler, @unchecked Sendable {
    public static let scheme = "archive-stage"

    private let apiClient: APIClient
    private let diskCache: DiskAssetCache
    private let previewLock = NSLock()
    private var previewGLBData: Data?
    private var activeTasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private let taskLock = NSLock()

    public init(apiClient: APIClient, diskCache: DiskAssetCache) {
        self.apiClient = apiClient
        self.diskCache = diskCache
        super.init()
    }

    public func setPreviewGLB(_ data: Data?) {
        previewLock.lock()
        previewGLBData = data
        previewLock.unlock()
    }

    public func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        let taskKey = ObjectIdentifier(urlSchemeTask as AnyObject)
        let host = url.host?.lowercased() ?? "app"

        let asyncTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.taskLock.lock()
                self.activeTasks[taskKey] = nil
                self.taskLock.unlock()
            }

            do {
                let (data, mimeType) = try await self.resolveResource(host: host, url: url)
                try Task.checkCancellation()
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: [
                        "Content-Type": mimeType,
                        "Content-Length": "\(data.count)",
                        "Access-Control-Allow-Origin": "*",
                        "Cache-Control": host == "preview" ? "no-store" : "public, max-age=31536000"
                    ]
                )!
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
            } catch is CancellationError {
                return
            } catch let apiError as ArchiveAPIError {
                let status = apiError.statusCode ?? 502
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: status,
                    httpVersion: "HTTP/1.1",
                    headerFields: [
                        "Content-Type": "text/plain; charset=utf-8",
                        "Access-Control-Allow-Origin": "*"
                    ]
                )!
                let body = Data((apiError.errorDescription ?? "Failed to load scan").utf8)
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(body)
                urlSchemeTask.didFinish()
            } catch {
                urlSchemeTask.didFailWithError(error)
            }
        }

        taskLock.lock()
        activeTasks[taskKey] = asyncTask
        taskLock.unlock()
    }

    public func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        let taskKey = ObjectIdentifier(urlSchemeTask as AnyObject)
        taskLock.lock()
        let running = activeTasks.removeValue(forKey: taskKey)
        taskLock.unlock()
        running?.cancel()
    }

    private func resolveResource(host: String, url: URL) async throws -> (Data, String) {
        switch host {
        case "app":
            return try loadBundledStageAsset(path: url.path)
        case "preview":
            previewLock.lock()
            let data = previewGLBData
            previewLock.unlock()
            guard let data else {
                throw URLError(.fileDoesNotExist)
            }
            return (data, "model/gltf-binary")
        case "models":
            let remotePath = url.path
            let data = try await diskCache.fetchOrLoad(remotePath: remotePath) { [apiClient] in
                let (bytes, _) = try await apiClient.downloadRawData(from: remotePath)
                return bytes
            }
            return (data, "model/gltf-binary")
        default:
            throw URLError(.unsupportedURL)
        }
    }

    private func loadBundledStageAsset(path: String) throws -> (Data, String) {
        let cleanRel = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let relative = cleanRel.isEmpty ? "index.html" : cleanRel

        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent("StageDist", isDirectory: true).appendingPathComponent(relative),
            Bundle.main.resourceURL?.appendingPathComponent(relative)
        ]

        for candidate in candidates.compactMap({ $0 }) {
            if FileManager.default.fileExists(atPath: candidate.path),
               let data = try? Data(contentsOf: candidate) {
                return (data, Self.mimeType(for: candidate.pathExtension))
            }
        }
        throw URLError(.fileDoesNotExist)
    }

    private static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "js", "mjs": return "text/javascript; charset=utf-8"
        case "wasm": return "application/wasm"
        case "css": return "text/css; charset=utf-8"
        case "glb": return "model/gltf-binary"
        case "json": return "application/json; charset=utf-8"
        default: return "application/octet-stream"
        }
    }
}
#endif

