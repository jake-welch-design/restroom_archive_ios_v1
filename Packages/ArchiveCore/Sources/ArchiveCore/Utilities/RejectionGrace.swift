import Foundation

public enum RejectionGrace {
    public static let graceDays: Int = 30
    private static let dayMs: Int64 = 24 * 60 * 60 * 1_000

    public static func msLeft(rejectedAt: String?, from nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1_000)) -> Int64? {
        guard let rejectedMs = ArchiveDateFormatter.parseSqliteUtcMs(rejectedAt) else {
            return nil
        }
        return rejectedMs + Int64(graceDays) * dayMs - nowMs
    }

    public static func formatCountdown(msLeft: Int64) -> String {
        if msLeft <= 0 {
            return "Expired"
        }
        let hours = Double(msLeft) / (60.0 * 60.0 * 1_000.0)
        if hours < 1.0 {
            return "Under an hour left"
        }
        if hours < 48.0 {
            let h = Int(floor(hours))
            return "\(h) hour\(h == 1 ? "" : "s") left"
        }
        let days = Int(msLeft / dayMs)
        return "\(days) days left"
    }
}

