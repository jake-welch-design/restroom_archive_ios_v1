import Foundation

public struct MultipartFormData: Sendable {
    public let boundary: String
    private var body = Data()

    public init(boundary: String = "ArchiveBoundary-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))") {
        self.boundary = boundary
    }

    public var contentTypeHeader: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    public mutating func appendField(name: String, value: String) {
        let header = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(escaped(name))\"\r\n\r\n"
        body.append(Data(header.utf8))
        body.append(Data(value.utf8))
        body.append(Data("\r\n".utf8))
    }

    public mutating func appendFile(
        name: String,
        filename: String,
        mimeType: String,
        fileData: Data
    ) {
        let header = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(escaped(name))\"; filename=\"\(escaped(filename))\"\r\nContent-Type: \(mimeType)\r\n\r\n"
        body.append(Data(header.utf8))
        body.append(fileData)
        body.append(Data("\r\n".utf8))
    }

    public func finalize() -> Data {
        var result = body
        result.append(Data("--\(boundary)--\r\n".utf8))
        return result
    }

    private func escaped(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }
}

