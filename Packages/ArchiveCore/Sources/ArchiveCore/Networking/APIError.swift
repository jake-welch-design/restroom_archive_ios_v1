import Foundation

public struct ArchiveServerErrorPayload: Decodable, Sendable {
    public var statusCode: Int?
    public var statusMessage: String?
    public var message: String?
}

public enum ArchiveAPIError: LocalizedError, Sendable, Equatable {
    case invalidURL(String)
    case httpStatus(code: Int, message: String, retryAfterSeconds: Int?)
    case decodingFailed(String)
    case networkFailure(String)
    case fileTooLarge(Int64)
    case invalidGLBFile

    public var statusCode: Int? {
        if case let .httpStatus(code, _, _) = self {
            return code
        }
        return nil
    }

    public var isRateLimited: Bool {
        statusCode == 429
    }

    public var isUnauthorized: Bool {
        statusCode == 401
    }

    public var errorDescription: String? {
        switch self {
        case let .invalidURL(raw):
            return "Invalid URL: \(raw)"
        case let .httpStatus(code, message, _):
            if !message.isEmpty { return message }
            return "Request failed (\(code))."
        case let .decodingFailed(reason):
            return "Unexpected server response (\(reason))."
        case let .networkFailure(reason):
            return reason
        case let .fileTooLarge(bytes):
            return UploadLimits.oversizedErrorMessage(for: bytes)
        case .invalidGLBFile:
            return "The selected file is not a valid binary .glb 3D model."
        }
    }

    public static func fromHTTPResponse(statusCode: Int, data: Data, headers: [AnyHashable: Any]) -> ArchiveAPIError {
        let retryHeader = (headers["Retry-After"] as? String) ?? (headers["retry-after"] as? String)
        let retrySeconds = retryHeader.flatMap(Int.init)

        if let payload = try? JSONDecoder().decode(ArchiveServerErrorPayload.self, from: data) {
            let msg = (payload.statusMessage ?? payload.message ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !msg.isEmpty {
                return .httpStatus(code: statusCode, message: msg, retryAfterSeconds: retrySeconds)
            }
        }

        let fallback: String
        switch statusCode {
        case 401: fallback = "Please sign in to continue."
        case 403: fallback = "You do not have permission for that action."
        case 404: fallback = "Not found."
        case 409: fallback = "Conflict with an existing record."
        case 413: fallback = "Upload exceeds the 25 MB limit."
        case 429: fallback = "Too many requests. Please wait a moment and try again."
        default: fallback = "Server error (\(statusCode))."
        }
        return .httpStatus(code: statusCode, message: fallback, retryAfterSeconds: retrySeconds)
    }
}

