import Foundation

public enum UploadLimits {
    /// Decimal 25 MB, matching `shared/utils/uploadLimits.ts` (`25 * 1000 * 1000`).
    public static let maxGlbBytes: Int64 = 25 * 1_000 * 1_000
    public static let maxGlbMB: Int = 25

    public static func formatFileSize(_ bytes: Int64) -> String {
        if bytes < 1_000 {
            return "\(bytes) B"
        }
        if bytes < 1_000 * 1_000 {
            return String(format: "%.1f KB", Double(bytes) / 1_000.0)
        }
        return String(format: "%.1f MB", Double(bytes) / 1_000_000.0)
    }

    public static func oversizedErrorMessage(for byteCount: Int64) -> String {
        "This scan is \(formatFileSize(byteCount)), over the \(maxGlbMB) MB limit. Re-exporting with Draco compression, or decimating the mesh, will usually bring a room scan under it."
    }

    /// Validates binary glTF 2.0 header (`glTF` magic `0x46546C67` little-endian).
    public static func hasValidGLBMagic(_ headerBytes: Data) -> Bool {
        guard headerBytes.count >= 12 else { return false }
        let magic = headerBytes.prefix(4)
        return magic == Data([0x67, 0x6C, 0x54, 0x46])
    }
}

