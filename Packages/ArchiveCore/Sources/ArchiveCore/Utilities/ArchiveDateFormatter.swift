import Foundation

public enum ArchiveDateFormatter {
    private static let monthShort = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]

    public static func toUtcDate(_ value: String?) -> Date? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        let normalized: String
        if raw.count == 10, raw.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
            normalized = "\(raw)T00:00:00Z"
        } else if raw.range(of: #"^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}(:\d{2})?$"#, options: .regularExpression) != nil {
            let withT = raw.replacingOccurrences(of: " ", with: "T")
            normalized = withT.split(separator: ":").count == 2 ? "\(withT):00Z" : "\(withT)Z"
        } else {
            normalized = raw
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: normalized) {
            return d
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: normalized)
    }

    public static func parseSqliteUtcMs(_ value: String?) -> Int64? {
        guard let date = toUtcDate(value) else { return nil }
        return Int64(date.timeIntervalSince1970 * 1000.0)
    }

    public static func isWithinHours(_ value: String?, hours: Double, now: Date = Date()) -> Bool {
        guard let date = toUtcDate(value) else { return false }
        return now.timeIntervalSince(date) < hours * 3600.0
    }

    public static func isFuture(_ value: String?, now: Date = Date()) -> Bool {
        guard let date = toUtcDate(value) else { return false }
        return date > now
    }

    /// Formats as `05 Mar 2025` (archive primary date style).
    public static func formatDayMonthYear(_ value: String?) -> String {
        guard let date = toUtcDate(value) else { return value ?? "" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day, (1...12).contains(m) else {
            return value ?? ""
        }
        let dayPadded = d < 10 ? "0\(d)" : "\(d)"
        return "\(dayPadded) \(monthShort[m - 1]) \(y)"
    }

    /// Formats as `Mar 5, 2025` (annotation byline date style).
    public static func formatMonthDayYear(_ value: String?) -> String {
        guard let date = toUtcDate(value) else { return value ?? "" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day, (1...12).contains(m) else {
            return value ?? ""
        }
        return "\(monthShort[m - 1]) \(d), \(y)"
    }

    public static func isoDateString(from date: Date, timeZone: TimeZone = .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 2026
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    public static func dateFromIsoDateString(_ isoDate: String, timeZone: TimeZone = .current) -> Date? {
        let parts = isoDate.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2]) else {
            return nil
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))
    }
}

