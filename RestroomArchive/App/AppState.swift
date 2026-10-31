#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import Foundation
import Observation
import SwiftUI

public enum TopNavTab: String, CaseIterable, Hashable, Sendable {
    case catalog
    case submit
    case account
    case admin
    case info

    public var label: String {
        switch self {
        case .catalog: return "Catalog"
        case .submit: return "Submit"
        case .account: return "Account"
        case .admin: return "Admin"
        case .info: return "Info"
        }
    }
}

@MainActor
@Observable
public final class AppState {
    // MARK: - Core Services
    public let apiClient: APIClient
    public let diskCache: DiskAssetCache
    public let draftStore: DraftSubmissionStore
    public let viewedPinsStore: ViewedPinsStore
    public let stageController: StageController
    public let locationService: LocationService

    // MARK: - Navigation & Sheet State
    public var activeTab: TopNavTab = .catalog
    public var pendingTabAfterDiscardAlert: TopNavTab?
    public var showUnsavedSubmissionAlert: Bool = false

    // MARK: - Catalog & Filter State
    public var restrooms: [RestroomSummary] = []
    public var isLoadingCatalog: Bool = false
    public var catalogError: String?
    public var searchQuery: String = ""
    public var selectedTags: Set<String> = []
    public var datePreset: DateRangePreset = .all
    public var viewMode: CatalogViewMode = .list
    public var sortField: CatalogSortField = .date
    public var sortDirection: SortDirection = .desc
    public var viewedSlugs: Set<String> = []
    public var basemapStyle: MapBasemapStyle = .default

    // MARK: - Active Selection & Spatial Annotations
    public var selectedSlug: String?
    public var annotations: [Annotation] = []
    public var isLoadingAnnotations: Bool = false
    public var selectedAnnotationId: Int?
    public var pendingPickedPoint: (point: Vec3, snapshot: CameraSnapshot)?

    // MARK: - Stage Override (Wizard Local Preview or Admin Pending Preview)
    public var hasUnsavedSubmissionPreview: Bool = false
    public var adminPreviewEntry: PendingRestroom?

    // MARK: - Session, Blocklist, Metadata & Draft Handoff
    public var currentUser: SessionUser?
    public var isBootstrappingSession: Bool = true
    public var blockedUsers: [BlockedUser] = []
    public var stats: SiteStats = SiteStats(restrooms: 0, cities: 0, countries: nil, archivists: 0)
    public var descriptorSuggestions: [String] = []
    public var pendingDraftIdToOpen: UUID?
    public var globalBannerMessage: String?

    // MARK: - Admin Queue Badge Counts
    public var adminPendingCount: Int = 0
    public var adminUpgradesCount: Int = 0
    public var adminRemovalsCount: Int = 0
    public var adminReportsCount: Int = 0

    @ObservationIgnored private var annotationLoadTask: Task<Void, Never>?
    @ObservationIgnored private var bannerTask: Task<Void, Never>?

    public init(baseURL: URL = APIClient.defaultBaseURL) {
        let tokenStore = KeychainStore()
        let client = APIClient(baseURL: baseURL, tokenStore: tokenStore)
        let cache = DiskAssetCache()
        let drafts = DraftSubmissionStore()
        let pins = ViewedPinsStore()
        let stage = StageController(apiClient: client, diskCache: cache)
        let location = LocationService()

        self.apiClient = client
        self.diskCache = cache
        self.draftStore = drafts
        self.viewedPinsStore = pins
        self.stageController = stage
        self.locationService = location
        self.viewedSlugs = pins.loadViewedSlugs()
        self.basemapStyle = pins.loadBasemap()

        stage.onAnnotationTapped = { [weak self] id in
            guard let self else { return }
            if self.selectedAnnotationId == id {
                self.selectAnnotation(nil, fly: false)
            } else {
                self.selectAnnotation(id, fly: true)
            }
        }

        stage.onPointPicked = { [weak self] point, snapshot in
            guard let self else { return }
            self.pendingPickedPoint = (point: point, snapshot: snapshot)
        }
    }

    // MARK: - Derived Properties

    public var blockedUsernames: Set<String> {
        Set(blockedUsers.map { $0.username.lowercased() })
    }

    public var visibleRestrooms: [RestroomSummary] {
        CatalogFiltering.filterRows(
            restrooms,
            query: searchQuery,
            selectedTags: selectedTags,
            datePreset: datePreset,
            blockedUsernames: blockedUsernames,
            sortField: sortField,
            sortDirection: sortDirection,
            userCoordinate: locationService.currentCoordinate
        )
    }

    public var visibleAnnotations: [Annotation] {
        let blocked = blockedUsernames
        return annotations.filter { !blocked.contains($0.author.username.lowercased()) }
    }

    public var selectedRestroom: RestroomSummary? {
        guard let selectedSlug else { return nil }
        return restrooms.first(where: { $0.slug == selectedSlug })
    }

    public var selectedAnnotation: Annotation? {
        guard let selectedAnnotationId else { return nil }
        return visibleAnnotations.first(where: { $0.id == selectedAnnotationId })
    }

    public var totalAdminActionCount: Int {
        adminPendingCount + adminUpgradesCount + adminRemovalsCount + adminReportsCount
    }

    public var availableTabs: [TopNavTab] {
        if currentUser?.isAdmin == true {
            return [.catalog, .submit, .account, .admin, .info]
        }
        return [.catalog, .submit, .account, .info]
    }

    /// Entry whose crop can currently be edited by an admin in the 3D viewer.
    public var activeCropTarget: (id: Int, slug: String, hasThumb: Bool)? {
        guard currentUser?.isAdmin == true, !hasUnsavedSubmissionPreview else {
            return nil
        }
        if let pending = adminPreviewEntry {
            return (id: pending.id, slug: pending.slug, hasThumb: false)
        }
        if let selected = selectedRestroom {
            return (id: selected.id, slug: selected.slug, hasThumb: selected.thumbUrl != nil)
        }
        return nil
    }

    // MARK: - Bootstrap & Refresh

    public func bootstrap() async {
        // Seed offline catalog snapshot immediately while network requests are in flight
        if restrooms.isEmpty, let cached = await diskCache.loadCatalogSnapshot(), !cached.isEmpty {
            restrooms = cached
            if selectedSlug == nil, let initial = visibleRestrooms.first {
                selectRestroom(slug: initial.slug)
            }
        }

        async let catalogTask: Void = refreshCatalog(selectFirstIfEmpty: true)
        async let sessionTask: Void = refreshSession()
        async let statsTask: Void = refreshStats()
        async let descriptorsTask: Void = refreshDescriptors()
        _ = await (catalogTask, sessionTask, statsTask, descriptorsTask)
    }

    public func refreshCatalog(selectFirstIfEmpty: Bool = false) async {
        isLoadingCatalog = true
        catalogError = nil
        do {
            let fetched = try await apiClient.fetchRestrooms()
            restrooms = fetched
            await diskCache.saveCatalogSnapshot(fetched)
            if let slug = selectedSlug,
               let updated = fetched.first(where: { $0.slug == slug }),
               !hasUnsavedSubmissionPreview,
               adminPreviewEntry == nil {
                // Keep crop synced if updated
                stageController.loadEntry(
                    slug: updated.slug,
                    remoteModelPath: updated.modelUrl,
                    crop: updated.crop,
                    annotations: visibleAnnotations,
                    selectedAnnotationId: selectedAnnotationId
                )
            } else if selectFirstIfEmpty, selectedSlug == nil, let first = visibleRestrooms.first {
                selectRestroom(slug: first.slug)
            }
        } catch {
            if restrooms.isEmpty {
                catalogError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
        isLoadingCatalog = false
    }

    public func refreshSession() async {
        isBootstrappingSession = true
        defer { isBootstrappingSession = false }

        guard let token = await apiClient.tokenStore.readToken(), !token.isEmpty else {
            currentUser = nil
            blockedUsers = []
            resetAdminBadges()
            return
        }

        do {
            let user = try await apiClient.fetchSession()
            currentUser = user
            if let user {
                await refreshBlockedUsers()
                if user.isAdmin {
                    await refreshAdminBadgeCounts()
                } else {
                    resetAdminBadges()
                }
            } else {
                try? await apiClient.tokenStore.clearToken()
                blockedUsers = []
                resetAdminBadges()
            }
        } catch {
            // Keep existing token if offline; clear only on explicit 401
            if case let ArchiveAPIError.serverError(status, _) = error, status == 401 {
                try? await apiClient.tokenStore.clearToken()
                currentUser = nil
                blockedUsers = []
                resetAdminBadges()
            }
        }
    }

    public func refreshStats() async {
        if let fetched = try? await apiClient.fetchStats() {
            stats = fetched
        }
    }

    public func refreshDescriptors() async {
        if let fetched = try? await apiClient.fetchDescriptors() {
            descriptorSuggestions = fetched
        }
    }

    public func refreshBlockedUsers() async {
        guard currentUser != nil else {
            blockedUsers = []
            return
        }
        if let list = try? await apiClient.fetchBlockedUsers() {
            blockedUsers = list
            stageController.syncAnnotations(visibleAnnotations, selectedId: selectedAnnotationId)
        }
    }

    public func refreshAdminBadgeCounts() async {
        guard currentUser?.isAdmin == true else {
            resetAdminBadges()
            return
        }
        async let pending = try? apiClient.fetchAdminPendingRestrooms()
        async let upgrades = try? apiClient.fetchAdminPendingUsers()
        async let removals = try? apiClient.fetchAdminRemovals()
        async let reports = try? apiClient.fetchAdminAnnotationReports()

        let (p, u, r, rep) = await (pending, upgrades, removals, reports)
        adminPendingCount = p?.count ?? 0
        adminUpgradesCount = u?.count ?? 0
        adminRemovalsCount = r?.count ?? 0
        adminReportsCount = rep?.count ?? 0
    }

    private func resetAdminBadges() {
        adminPendingCount = 0
        adminUpgradesCount = 0
        adminRemovalsCount = 0
        adminReportsCount = 0
    }

    // MARK: - Navigation & Selection Actions

    public func requestTabSwitch(_ destination: TopNavTab) {
        guard destination != activeTab else { return }
        if activeTab == .submit && hasUnsavedSubmissionPreview {
            pendingTabAfterDiscardAlert = destination
            showUnsavedSubmissionAlert = true
            return
        }
        performTabSwitch(destination)
    }

    public func confirmDiscardUnsavedSubmissionAndSwitch() {
        hasUnsavedSubmissionPreview = false
        restoreSelectedRestroomOnStage()
        if let next = pendingTabAfterDiscardAlert {
            pendingTabAfterDiscardAlert = nil
            performTabSwitch(next)
        }
    }

    private func performTabSwitch(_ destination: TopNavTab) {
        if activeTab == .admin && destination != .admin && adminPreviewEntry != nil {
            adminPreviewEntry = nil
            restoreSelectedRestroomOnStage()
        }
        activeTab = destination
    }

    public func selectRestroom(slug: String, initialAnnotationId: Int? = nil) {
        adminPreviewEntry = nil
        hasUnsavedSubmissionPreview = false
        pendingPickedPoint = nil
        stageController.setCreateMode(false)

        selectedSlug = slug
        selectedAnnotationId = initialAnnotationId
        viewedSlugs = viewedPinsStore.markViewed(slug: slug)

        guard let entry = restrooms.first(where: { $0.slug == slug }) else {
            return
        }

        annotations = []
        stageController.loadEntry(
            slug: entry.slug,
            remoteModelPath: entry.modelUrl,
            crop: entry.crop,
            annotations: [],
            selectedAnnotationId: nil
        )

        annotationLoadTask?.cancel()
        annotationLoadTask = Task { [weak self] in
            await self?.loadAnnotations(for: slug, selectAfterLoad: initialAnnotationId)
        }
    }

    public func stepSelection(delta: Int) {
        let rows = visibleRestrooms
        guard !rows.isEmpty else { return }
        if let currentSlug = selectedSlug,
           let idx = rows.firstIndex(where: { $0.slug == currentSlug }) {
            let nextIdx = (idx + delta + rows.count) % rows.count
            selectRestroom(slug: rows[nextIdx].slug)
        } else {
            selectRestroom(slug: rows[0].slug)
        }
    }

    public func selectRandomRestroom() {
        let pool = visibleRestrooms.isEmpty ? restrooms : visibleRestrooms
        if let chosen = CatalogFiltering.randomEntry(from: pool, excluding: selectedSlug) {
            selectRestroom(slug: chosen.slug)
        }
    }

    public func sortCatalogByNearMe() async {
        do {
            _ = try await locationService.requestSingleLocation()
            sortField = .distance
            sortDirection = .asc
            showBanner("Sorted by distance from your location")
        } catch {
            showBanner(error.localizedDescription)
        }
    }

    public func setBasemapStyle(_ style: MapBasemapStyle) {
        basemapStyle = style
        viewedPinsStore.saveBasemap(style)
    }

    public func toggleTagFilter(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    public func clearAllFilters() {
        searchQuery = ""
        selectedTags.removeAll()
        datePreset = .all
    }

    // MARK: - Stage Previews (Submit Wizard & Admin Review)

    public func startLocalSubmissionPreview(glbData: Data) {
        adminPreviewEntry = nil
        hasUnsavedSubmissionPreview = true
        stageController.loadLocalPreview(glbData: glbData)
    }

    public func endLocalSubmissionPreview() {
        hasUnsavedSubmissionPreview = false
        restoreSelectedRestroomOnStage()
    }

    public func previewAdminPendingEntry(_ pending: PendingRestroom) {
        hasUnsavedSubmissionPreview = false
        adminPreviewEntry = pending
        stageController.loadEntry(
            slug: pending.slug,
            remoteModelPath: pending.modelUrl,
            crop: pending.crop,
            annotations: [],
            selectedAnnotationId: nil
        )
    }

    public func clearAdminPendingPreview() {
        guard adminPreviewEntry != nil else { return }
        adminPreviewEntry = nil
        restoreSelectedRestroomOnStage()
    }

    public func restoreSelectedRestroomOnStage() {
        if let entry = selectedRestroom {
            stageController.loadEntry(
                slug: entry.slug,
                remoteModelPath: entry.modelUrl,
                crop: entry.crop,
                annotations: visibleAnnotations,
                selectedAnnotationId: selectedAnnotationId
            )
        } else {
            stageController.clearScan()
        }
    }

    public func reloadCurrentScan() {
        if let pending = adminPreviewEntry {
            previewAdminPendingEntry(pending)
        } else {
            restoreSelectedRestroomOnStage()
        }
    }

    // MARK: - Spatial Annotations & UGC Moderation

    public func loadAnnotations(for slug: String, selectAfterLoad: Int? = nil) async {
        isLoadingAnnotations = true
        defer { isLoadingAnnotations = false }
        do {
            let fetched = try await apiClient.fetchAnnotations(slug: slug)
            guard !Task.isCancelled, selectedSlug == slug else { return }
            annotations = fetched
            stageController.syncAnnotations(visibleAnnotations, selectedId: selectAfterLoad ?? selectedAnnotationId)
            if let targetId = selectAfterLoad {
                stageController.selectAnnotation(id: targetId, fly: true)
            }
        } catch {
            // Non-fatal
        }
    }

    public func selectAnnotation(_ id: Int?, fly: Bool = true) {
        selectedAnnotationId = id
        stageController.selectAnnotation(id: id, fly: fly)
    }

    public func createAnnotation(body: String) async throws {
        guard let slug = selectedSlug, let picked = pendingPickedPoint else { return }
        let payload = CreateAnnotationBody(
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            point: picked.point,
            snapshot: picked.snapshot
        )
        try await apiClient.createAnnotation(slug: slug, payload: payload)
        pendingPickedPoint = nil
        stageController.setCreateMode(false)
        await loadAnnotations(for: slug)
        if let newest = visibleAnnotations.last {
            selectAnnotation(newest.id, fly: false)
        }
        stageController.showToast("Annotation saved")
    }

    public func deleteAnnotation(_ annotationId: Int) async throws {
        guard let slug = selectedSlug else { return }
        try await apiClient.deleteAnnotation(slug: slug, annotationId: annotationId)
        if selectedAnnotationId == annotationId {
            selectedAnnotationId = nil
        }
        await loadAnnotations(for: slug)
        stageController.showToast("Annotation deleted")
    }

    public func blockAuthor(username: String) async {
        guard currentUser != nil else {
            requestTabSwitch(.account)
            showBanner("Sign in to block accounts.")
            return
        }
        do {
            try await apiClient.blockUser(username: username)
            await refreshBlockedUsers()
            if let selected = selectedRestroom,
               selected.submitter?.username.lowercased() == username.lowercased() {
                if let next = visibleRestrooms.first {
                    selectRestroom(slug: next.slug)
                }
            }
            showBanner("Blocked @\(username). Their entries and annotations are now hidden.")
        } catch {
            showBanner((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    public func unblockAuthor(username: String) async {
        do {
            try await apiClient.unblockUser(username: username)
            await refreshBlockedUsers()
            showBanner("Unblocked @\(username).")
        } catch {
            showBanner((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    // MARK: - Auth Lifecycle Helpers

    public func didAuthenticate(user: SessionUser) async {
        currentUser = user
        await refreshBlockedUsers()
        if user.isAdmin {
            await refreshAdminBadgeCounts()
        }
    }

    public func signOut() async {
        await apiClient.signOut()
        currentUser = nil
        blockedUsers = []
        resetAdminBadges()
        if activeTab == .admin {
            activeTab = .catalog
        }
        showBanner("Signed out.")
    }

    // MARK: - Deep Link & Universal Link Routing

    public func handleIncomingURL(_ url: URL) {
        // 1. Custom URL scheme: restroomarchive://submit-draft?id=<UUID> or restroomarchive://r/<slug>
        if url.scheme?.lowercased() == "restroomarchive" {
            let host = url.host?.lowercased() ?? ""
            if host == "submit-draft" {
                let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
                if let idStr = comps?.queryItems?.first(where: { $0.name == "id" })?.value,
                   let uuid = UUID(uuidString: idStr) {
                    pendingDraftIdToOpen = uuid
                    activeTab = .submit
                }
                return
            }
            if host == "r" {
                let slug = url.pathComponents.dropFirst().first ?? ""
                if !slug.isEmpty {
                    openRestroomSlugFromLink(slug)
                }
                return
            }
        }

        // 2. Universal Link: https://restroomarchive.com/r/<slug>
        let parts = url.pathComponents.filter { $0 != "/" }
        if parts.count >= 2, parts[0] == "r" {
            openRestroomSlugFromLink(parts[1])
        } else if parts.first == "submit" {
            requestTabSwitch(.submit)
        } else if parts.first == "account" {
            requestTabSwitch(.account)
        } else if parts.first == "about" {
            requestTabSwitch(.info)
        }
    }

    private func openRestroomSlugFromLink(_ slug: String) {
        activeTab = .catalog
        if restrooms.contains(where: { $0.slug == slug }) {
            selectRestroom(slug: slug)
        } else {
            Task {
                await refreshCatalog()
                if restrooms.contains(where: { $0.slug == slug }) {
                    selectRestroom(slug: slug)
                }
            }
        }
    }

    public func showBanner(_ message: String, durationSeconds: Double = 3.2) {
        globalBannerMessage = message
        bannerTask?.cancel()
        bannerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(durationSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.globalBannerMessage = nil
        }
    }
}
#endif

