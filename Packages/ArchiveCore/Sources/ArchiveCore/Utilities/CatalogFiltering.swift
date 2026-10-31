import Foundation

public enum CatalogViewMode: String, Codable, CaseIterable, Sendable {
    case list
    case grid
    case map

    public var label: String {
        switch self {
        case .list: return "List"
        case .grid: return "Grid"
        case .map: return "Map"
        }
    }
}

public enum CatalogSortField: String, Codable, CaseIterable, Sendable {
    case date
    case name
    case location
    case distance

    public var label: String {
        switch self {
        case .date: return "Date"
        case .name: return "Name"
        case .location: return "Location"
        case .distance: return "Distance"
        }
    }
}

public enum SortDirection: String, Codable, Sendable {
    case asc
    case desc

    public mutating func toggle() {
        self = (self == .asc) ? .desc : .asc
    }
}

public enum DateRangePreset: String, Codable, CaseIterable, Sendable {
    case all
    case past30Days
    case pastYear
    case year2026
    case year2025
    case earlier

    public var label: String {
        switch self {
        case .all: return "All dates"
        case .past30Days: return "Last 30 days"
        case .pastYear: return "Last 12 months"
        case .year2026: return "2026"
        case .year2025: return "2025"
        case .earlier: return "2024 & earlier"
        }
    }

    public func matches(isoDate: String, now: Date = Date()) -> Bool {
        switch self {
        case .all:
            return true
        case .past30Days:
            guard let d = ArchiveDateFormatter.toUtcDate(isoDate) else { return false }
            return now.timeIntervalSince(d) <= 30 * 86_400
        case .pastYear:
            guard let d = ArchiveDateFormatter.toUtcDate(isoDate) else { return false }
            return now.timeIntervalSince(d) <= 365 * 86_400
        case .year2026:
            return isoDate.hasPrefix("2026")
        case .year2025:
            return isoDate.hasPrefix("2025")
        case .earlier:
            guard let yearPrefix = Int(isoDate.prefix(4)) else { return false }
            return yearPrefix <= 2024
        }
    }
}

public enum CatalogFiltering {
    /// Public directory rows exclude admin-visible `pending` entries unless requested,
    /// and exclude entries submitted by accounts on the signed-in user's blocklist.
    public static func filterRows(
        _ rows: [RestroomSummary],
        query: String,
        selectedTags: Set<String>,
        datePreset: DateRangePreset = .all,
        blockedUsernames: Set<String> = [],
        sortField: CatalogSortField = .date,
        sortDirection: SortDirection = .desc,
        userCoordinate: (lat: Double, lng: Double)? = nil,
        now: Date = Date()
    ) -> [RestroomSummary] {
        let normalizedBlocks = Set(blockedUsernames.map { $0.lowercased() })
        let tokens = query
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        let filtered = rows.filter { row in
            guard row.status == "published" else { return false }

            if let submitter = row.submitter?.username.lowercased(),
               normalizedBlocks.contains(submitter) {
                return false
            }

            if !selectedTags.isEmpty {
                let rowTagSet = Set(row.descriptors.map { $0.lowercased() })
                for required in selectedTags where !rowTagSet.contains(required.lowercased()) {
                    return false
                }
            }

            if !datePreset.matches(isoDate: row.isoDate, now: now) {
                return false
            }

            guard !tokens.isEmpty else { return true }

            let haystack = [
                row.name,
                row.location,
                row.country.flatMap(Regions.countryName(for:)) ?? "",
                row.description ?? "",
                row.descriptors.joined(separator: " "),
                row.submitter?.username ?? "",
                row.submitter?.displayName ?? "",
                row.date,
                row.isoDate
            ]
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en"))
                .lowercased()

            return tokens.allSatisfy { token in
                let foldedToken = token.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en")).lowercased()
                return haystack.contains(foldedToken) || fuzzySubsequenceScore(token: foldedToken, in: row.name.lowercased()) > 0
            }
        }

        return filtered.sorted { a, b in
            let comparison: ComparisonResult
            switch sortField {
            case .date:
                if a.isoDate != b.isoDate {
                    comparison = a.isoDate < b.isoDate ? .orderedAscending : .orderedDescending
                } else {
                    comparison = a.id < b.id ? .orderedAscending : (a.id > b.id ? .orderedDescending : .orderedSame)
                }
            case .name:
                comparison = a.name.localizedCaseInsensitiveCompare(b.name)
            case .location:
                comparison = a.location.localizedCaseInsensitiveCompare(b.location)
            case .distance:
                if let userCoordinate {
                    let distA = distanceMeters(from: userCoordinate, to: a) ?? .greatestFiniteMagnitude
                    let distB = distanceMeters(from: userCoordinate, to: b) ?? .greatestFiniteMagnitude
                    if distA != distB {
                        comparison = distA < distB ? .orderedAscending : .orderedDescending
                    } else {
                        comparison = a.name.localizedCaseInsensitiveCompare(b.name)
                    }
                } else {
                    comparison = a.isoDate < b.isoDate ? .orderedAscending : .orderedDescending
                }
            }

            if sortDirection == .asc {
                return comparison == .orderedAscending
            } else {
                return comparison == .orderedDescending
            }
        }
    }

    public static func allDescriptorCounts(in rows: [RestroomSummary]) -> [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for row in rows where row.status == "published" {
            for tag in row.descriptors {
                counts[tag, default: 0] += 1
            }
        }
        return counts
            .map { (tag: $0.key, count: $0.value) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.tag.localizedCaseInsensitiveCompare(b.tag) == .orderedAscending
            }
    }

    /// Picks a random published entry from `rows`, avoiding `currentSlug` when alternatives exist.
    public static func randomEntry(from rows: [RestroomSummary], excluding currentSlug: String?) -> RestroomSummary? {
        let published = rows.filter { $0.status == "published" }
        guard !published.isEmpty else { return nil }
        if published.count == 1 { return published[0] }
        let candidates = published.filter { $0.slug != currentSlug }
        return (candidates.isEmpty ? published : candidates).randomElement()
    }

    /// Great-circle Haversine distance in meters.
    public static func distanceMeters(
        from origin: (lat: Double, lng: Double),
        to restroom: RestroomSummary
    ) -> Double? {
        guard let lat2 = restroom.lat, let lng2 = restroom.lng else { return nil }
        let earthRadius = 6_371_000.0
        let dLat = (lat2 - origin.lat) * .pi / 180.0
        let dLng = (lng2 - origin.lng) * .pi / 180.0
        let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(origin.lat * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
            sin(dLng / 2) * sin(dLng / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }

    public static func formatDistance(_ meters: Double) -> String {
        if meters < 1_000 {
            return "\(Int(meters.rounded())) m"
        }
        let km = meters / 1_000.0
        if km < 10 {
            return String(format: "%.1f km", km)
        }
        return "\(Int(km.rounded())) km"
    }

    private static func fuzzySubsequenceScore(token: String, in target: String) -> Int {
        guard token.count >= 3 else { return 0 }
        var tokenIdx = token.startIndex
        var consecutive = 0
        var bestRun = 0
        for ch in target {
            if tokenIdx < token.endIndex, ch == token[tokenIdx] {
                tokenIdx = token.index(after: tokenIdx)
                consecutive += 1
                bestRun = max(bestRun, consecutive)
            } else {
                consecutive = 0
            }
        }
        return (tokenIdx == token.endIndex && bestRun >= 2) ? bestRun : 0
    }
}

