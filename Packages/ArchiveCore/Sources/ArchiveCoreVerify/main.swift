import ArchiveCore
import Foundation

private func check(_ condition: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
    if !condition() {
        fputs("FAIL (line \(line)): \(message)\n", stderr)
        exit(1)
    }
}

private func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String, line: Int = #line) {
    if actual != expected {
        fputs("FAIL (line \(line)): \(label) — got \(actual), expected \(expected)\n", stderr)
        exit(1)
    }
}

@main
struct ArchiveCoreVerifyMain {
    static func main() async throws {
        // 1. Regions composition, reverse-geocode normalization, coordinate parsing
        checkEqual(
            Regions.composeLocation(city: "Brooklyn", country: "US", subdivision: "NY"),
            "Brooklyn, NY",
            "composeLocation US"
        )
        checkEqual(
            Regions.composeLocation(city: "Toronto, ", country: "CA", subdivision: "ON"),
            "Toronto, ON",
            "composeLocation CA trailing comma"
        )
        checkEqual(
            Regions.composeLocation(city: "Reykjavik", country: "IS", subdivision: nil),
            "Reykjavik, IS",
            "composeLocation non-subdivided"
        )

        let prNormalized = Regions.normalizeReverseGeocodedRegion(isoCountryCode: "PR", administrativeArea: nil)
        checkEqual(prNormalized.country, "US", "PR country normalized")
        checkEqual(prNormalized.subdivision, "PR", "PR subdivision normalized")

        let nyNormalized = Regions.normalizeReverseGeocodedRegion(isoCountryCode: "us", administrativeArea: "New York")
        checkEqual(nyNormalized.country, "US", "NY country")
        checkEqual(nyNormalized.subdivision, "NY", "NY state code")

        let parsed = Regions.parseCoordinatePair(" 40.7128 , -74.0060 ")
        checkEqual(parsed?.lat, "40.7128", "parsed lat")
        checkEqual(parsed?.lng, "-74.0060", "parsed lng")
        check(Regions.parseCoordinatePair("95.0, -74.0") == nil, "out-of-range latitude rejected")

        // 2. Date formatting
        checkEqual(ArchiveDateFormatter.formatDayMonthYear("2025-03-05"), "05 Mar 2025", "ISO date format")
        checkEqual(ArchiveDateFormatter.formatDayMonthYear("2025-03-05 23:45:12"), "05 Mar 2025", "SQLite UTC format")
        checkEqual(ArchiveDateFormatter.formatMonthDayYear("2025-03-05 23:45:12"), "Mar 5, 2025", "Month day year")

        // 3. Upload limits & GLB magic header
        checkEqual(UploadLimits.maxGlbBytes, 25_000_000, "25 MB decimal byte cap")
        checkEqual(UploadLimits.formatFileSize(950), "950 B", "bytes format")
        checkEqual(UploadLimits.formatFileSize(42_500), "42.5 KB", "KB format")
        checkEqual(UploadLimits.formatFileSize(26_214_400), "26.2 MB", "MB format")

        var validHeader = Data([0x67, 0x6C, 0x54, 0x46])
        validHeader.append(contentsOf: [0x02, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00])
        check(UploadLimits.hasValidGLBMagic(validHeader), "valid GLB magic")
        check(!UploadLimits.hasValidGLBMagic(Data("not-a-glb-file".utf8)), "invalid GLB magic")

        // 4. Rejection grace countdown
        let baseMs = ArchiveDateFormatter.parseSqliteUtcMs("2026-01-01 00:00:00")!
        let twentyDaysIn = baseMs + 20 * 24 * 60 * 60 * 1_000
        let left = RejectionGrace.msLeft(rejectedAt: "2026-01-01 00:00:00", from: twentyDaysIn)!
        checkEqual(RejectionGrace.formatCountdown(msLeft: left), "10 days left", "10 days left")
        checkEqual(RejectionGrace.formatCountdown(msLeft: 30 * 60 * 1_000), "Under an hour left", "under an hour")
        checkEqual(RejectionGrace.formatCountdown(msLeft: 0), "Expired", "expired")

        // 5. Catalog filtering, tag intersection, blocklist, Haversine sort
        let rows: [RestroomSummary] = [
            RestroomSummary(
                id: 1,
                slug: "bemelmans-bar",
                name: "Bemelmans Bar",
                location: "New York, NY",
                country: "US",
                lat: 40.7744,
                lng: -73.9631,
                date: "05 Mar 2026",
                isoDate: "2026-03-05",
                description: "Marble wainscoting and brass sconces.",
                descriptors: ["accessible", "hotel", "marble"],
                submitter: PublicUserRef(username: "alice", displayName: "Alice"),
                status: "published",
                modelUrl: "/api/r2/models/1.glb"
            ),
            RestroomSummary(
                id: 2,
                slug: "tokyo-station",
                name: "Tokyo Station North",
                location: "Tokyo, JP",
                country: "JP",
                lat: 35.6812,
                lng: 139.7671,
                date: "10 Apr 2026",
                isoDate: "2026-04-10",
                description: "Minimalist tilework with heated bidet.",
                descriptors: ["transit", "accessible"],
                submitter: PublicUserRef(username: "bob", displayName: "Bob"),
                status: "published",
                modelUrl: "/api/r2/models/2.glb"
            ),
            RestroomSummary(
                id: 3,
                slug: "pending-entry",
                name: "Pending Entry",
                location: "Brooklyn, NY",
                country: "US",
                date: "12 Apr 2026",
                isoDate: "2026-04-12",
                status: "pending",
                modelUrl: "/api/r2/models/3.glb"
            )
        ]

        let visibleDefault = CatalogFiltering.filterRows(rows, query: "", selectedTags: [])
        checkEqual(visibleDefault.map(\.slug), ["tokyo-station", "bemelmans-bar"], "default published date desc")

        let afterBlock = CatalogFiltering.filterRows(rows, query: "", selectedTags: [], blockedUsernames: ["BOB"])
        checkEqual(afterBlock.map(\.slug), ["bemelmans-bar"], "case-insensitive blocklist")

        let byTags = CatalogFiltering.filterRows(rows, query: "brass", selectedTags: ["accessible", "hotel"])
        checkEqual(byTags.map(\.slug), ["bemelmans-bar"], "search + tag intersection")

        let nearMidtown = CatalogFiltering.filterRows(
            rows,
            query: "",
            selectedTags: [],
            sortField: .distance,
            sortDirection: .asc,
            userCoordinate: (lat: 40.7580, lng: -73.9855)
        )
        checkEqual(nearMidtown.map(\.slug), ["bemelmans-bar", "tokyo-station"], "distance sort")

        // 6. StageBridge JSON wire format
        let cmd = StageCommand.loadScan(
            url: "archive-stage://models/api/r2/models/test.glb",
            slug: "test-slug",
            crop: nil,
            annotations: [],
            selectedAnnotationId: nil
        )
        let encoded = try JSONEncoder().encode(cmd)
        let jsonObj = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        checkEqual(jsonObj?["type"] as? String, "loadScan", "StageCommand wire type")
        checkEqual(jsonObj?["slug"] as? String, "test-slug", "StageCommand wire slug")

        let pickedJSON = """
        {
          "type": "pointPicked",
          "point": { "x": 1.25, "y": -0.5, "z": 3.0 },
          "snapshot": {
            "cameraMode": "pov",
            "cameraFov": 75,
            "modelRotationY": 0,
            "rotationX": -0.1,
            "rotationY": 1.5
          }
        }
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(StageEvent.self, from: pickedJSON)
        if case let .pointPicked(point, snapshot) = event {
            checkEqual(point, Vec3(x: 1.25, y: -0.5, z: 3.0), "pointPicked coordinates")
            checkEqual(snapshot.cameraMode, .pov, "snapshot mode")
            checkEqual(snapshot.cameraFov, 75, "snapshot fov")
        } else {
            check(false, "Expected pointPicked event")
        }

        // 7. Offline DraftSubmissionStore persistence
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArchiveDraftVerify-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = DraftSubmissionStore(customRootDirectory: tempDir)
        var glbBytes = Data([0x67, 0x6C, 0x54, 0x46, 0x02, 0x00, 0x00, 0x00, 0x14, 0x00, 0x00, 0x00])
        glbBytes.append(Data(repeating: 0x20, count: 8))

        var draft = try await store.createDraftFromGLB(
            data: glbBytes,
            originalFileName: "cafe.glb",
            city: "Brooklyn",
            country: "US",
            subdivision: "NY",
            name: "Corner Cafe"
        )
        checkEqual(draft.name, "Corner Cafe", "draft name")
        draft.description = "Green subway tile."
        try await store.updateDraft(draft)

        let listed = await store.listDrafts()
        checkEqual(listed.count, 1, "listed count")
        checkEqual(listed.first?.description, "Green subway tile.", "updated draft description")
        let storedBytes = await store.glbData(for: draft)
        checkEqual(storedBytes, glbBytes, "stored GLB roundtrip")

        try await store.deleteDraft(id: draft.id)
        let afterDelete = await store.listDrafts()
        check(afterDelete.isEmpty, "draft deleted")

        // 8. Submission agreements exactness
        checkEqual(SubmissionAgreements.all.count, 8, "8 submission agreements")
        check(SubmissionAgreements.all.last?.contains("sole, perpetual license") == true, "license clause")

        print("PASS: All 8 ArchiveCore verification suites succeeded.")
    }
}

