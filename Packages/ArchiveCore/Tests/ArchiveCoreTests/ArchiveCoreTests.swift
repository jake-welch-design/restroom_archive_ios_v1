import Foundation
import XCTest
@testable import ArchiveCore

final class ArchiveCoreTests: XCTestCase {
    func testRegionsLocationCompositionAndNormalization() {
        XCTAssertEqual(
            Regions.composeLocation(city: "Brooklyn", country: "US", subdivision: "NY"),
            "Brooklyn, NY"
        )
        XCTAssertEqual(
            Regions.composeLocation(city: "Toronto, ", country: "CA", subdivision: "ON"),
            "Toronto, ON"
        )
        XCTAssertEqual(
            Regions.composeLocation(city: "Reykjavik", country: "IS", subdivision: nil),
            "Reykjavik, IS"
        )

        let prNormalized = Regions.normalizeReverseGeocodedRegion(
            isoCountryCode: "PR",
            administrativeArea: nil
        )
        XCTAssertEqual(prNormalized.country, "US")
        XCTAssertEqual(prNormalized.subdivision, "PR")

        let nyNormalized = Regions.normalizeReverseGeocodedRegion(
            isoCountryCode: "us",
            administrativeArea: "New York"
        )
        XCTAssertEqual(nyNormalized.country, "US")
        XCTAssertEqual(nyNormalized.subdivision, "NY")

        let parsed = Regions.parseCoordinatePair(" 40.7128 , -74.0060 ")
        XCTAssertEqual(parsed?.lat, "40.7128")
        XCTAssertEqual(parsed?.lng, "-74.0060")
        XCTAssertNil(Regions.parseCoordinatePair("95.0, -74.0"))
    }

    func testArchiveDateFormatterMatchesWebOutput() {
        XCTAssertEqual(ArchiveDateFormatter.formatDayMonthYear("2025-03-05"), "05 Mar 2025")
        XCTAssertEqual(ArchiveDateFormatter.formatDayMonthYear("2025-03-05 23:45:12"), "05 Mar 2025")
        XCTAssertEqual(ArchiveDateFormatter.formatMonthDayYear("2025-03-05 23:45:12"), "Mar 5, 2025")
    }

    func testUploadLimitsAndGLBMagic() {
        XCTAssertEqual(UploadLimits.maxGlbBytes, 25_000_000)
        XCTAssertEqual(UploadLimits.formatFileSize(950), "950 B")
        XCTAssertEqual(UploadLimits.formatFileSize(42_500), "42.5 KB")
        XCTAssertEqual(UploadLimits.formatFileSize(26_214_400), "26.2 MB")

        var validHeader = Data([0x67, 0x6C, 0x54, 0x46])
        validHeader.append(contentsOf: [0x02, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00])
        XCTAssertTrue(UploadLimits.hasValidGLBMagic(validHeader))
        XCTAssertFalse(UploadLimits.hasValidGLBMagic(Data("not-a-glb-file".utf8)))
    }

    func testRejectionGraceCountdown() {
        let baseMs = ArchiveDateFormatter.parseSqliteUtcMs("2026-01-01 00:00:00")!
        let tenDaysIn = baseMs + 20 * 24 * 60 * 60 * 1_000
        let left = RejectionGrace.msLeft(rejectedAt: "2026-01-01 00:00:00", from: tenDaysIn)!
        XCTAssertEqual(RejectionGrace.formatCountdown(msLeft: left), "10 days left")
        XCTAssertEqual(RejectionGrace.formatCountdown(msLeft: 30 * 60 * 1_000), "Under an hour left")
        XCTAssertEqual(RejectionGrace.formatCountdown(msLeft: 0), "Expired")
    }

    func testCatalogFilteringSearchTagsBlocksAndDistanceSort() {
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
        XCTAssertEqual(visibleDefault.map(\.slug), ["tokyo-station", "bemelmans-bar"])

        let afterBlock = CatalogFiltering.filterRows(
            rows,
            query: "",
            selectedTags: [],
            blockedUsernames: ["BOB"]
        )
        XCTAssertEqual(afterBlock.map(\.slug), ["bemelmans-bar"])

        let byTags = CatalogFiltering.filterRows(
            rows,
            query: "brass",
            selectedTags: ["accessible", "hotel"]
        )
        XCTAssertEqual(byTags.map(\.slug), ["bemelmans-bar"])

        let nearMidtown = CatalogFiltering.filterRows(
            rows,
            query: "",
            selectedTags: [],
            sortField: .distance,
            sortDirection: .asc,
            userCoordinate: (lat: 40.7580, lng: -73.9855)
        )
        XCTAssertEqual(nearMidtown.map(\.slug), ["bemelmans-bar", "tokyo-station"])
    }

    func testStageBridgeProtocolSerialization() throws {
        let cmd = StageCommand.loadScan(
            url: "archive-stage://models/api/r2/models/test.glb",
            slug: "test-slug",
            crop: nil,
            annotations: [],
            selectedAnnotationId: nil
        )
        let encoded = try JSONEncoder().encode(cmd)
        let jsonObj = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        XCTAssertEqual(jsonObj?["type"] as? String, "loadScan")
        XCTAssertEqual(jsonObj?["slug"] as? String, "test-slug")

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
        guard case let .pointPicked(point, snapshot) = event else {
            return XCTFail("Expected pointPicked event")
        }
        XCTAssertEqual(point, Vec3(x: 1.25, y: -0.5, z: 3.0))
        XCTAssertEqual(snapshot.cameraMode, .pov)
        XCTAssertEqual(snapshot.cameraFov, 75)
    }

    func testDraftSubmissionStorePersistence() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArchiveDraftTests-\(UUID().uuidString)", isDirectory: true)
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
        XCTAssertEqual(draft.name, "Corner Cafe")

        draft.description = "Green subway tile."
        try await store.updateDraft(draft)

        let listed = await store.listDrafts()
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed.first?.description, "Green subway tile.")
        let storedBytes = await store.glbData(for: draft)
        XCTAssertEqual(storedBytes, glbBytes)

        try await store.deleteDraft(id: draft.id)
        let afterDelete = await store.listDrafts()
        XCTAssertTrue(afterDelete.isEmpty)
    }

    func testSubmissionAgreementsExactCountAndLicense() {
        XCTAssertEqual(SubmissionAgreements.all.count, 8)
        XCTAssertTrue(SubmissionAgreements.all.last?.contains("sole, perpetual license") == true)
    }
}

