import Foundation

public struct SubmitRestroomForm: Sendable {
    public var fileData: Data
    public var fileName: String
    public var name: String
    public var location: String
    public var country: String
    public var isoDate: String
    public var lat: String
    public var lng: String
    public var description: String
    public var descriptors: [String]

    public init(
        fileData: Data,
        fileName: String,
        name: String,
        location: String,
        country: String,
        isoDate: String,
        lat: String,
        lng: String,
        description: String,
        descriptors: [String]
    ) {
        self.fileData = fileData
        self.fileName = fileName
        self.name = name
        self.location = location
        self.country = country
        self.isoDate = isoDate
        self.lat = lat
        self.lng = lng
        self.description = description
        self.descriptors = descriptors
    }
}

public struct ContactFormRequest: Codable, Hashable, Sendable {
    public var name: String
    public var email: String
    public var subject: String
    public var body: String

    public init(name: String, email: String, subject: String, body: String) {
        self.name = name
        self.email = email
        self.subject = subject
        self.body = body
    }
}

public final class APIClient: Sendable {
    public static let defaultBaseURL = URL(string: "https://restroomarchive.com")!

    public let baseURL: URL
    public let tokenStore: any TokenStoring
    private let session: URLSession

    public init(
        baseURL: URL = APIClient.defaultBaseURL,
        tokenStore: any TokenStoring,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.session = session
    }

    public func resolveURL(_ relativeOrAbsolute: String) -> URL? {
        if relativeOrAbsolute.hasPrefix("http://") || relativeOrAbsolute.hasPrefix("https://") {
            return URL(string: relativeOrAbsolute)
        }
        let clean = relativeOrAbsolute.hasPrefix("/") ? relativeOrAbsolute : "/\(relativeOrAbsolute)"
        return URL(string: clean, relativeTo: baseURL)?.absoluteURL
    }

    // MARK: - Public Catalog & Stats

    public func fetchRestrooms() async throws -> [RestroomSummary] {
        try await request(method: "GET", path: "/api/restrooms")
    }

    public func fetchStats() async throws -> SiteStats {
        try await request(method: "GET", path: "/api/stats")
    }

    public func fetchDescriptors() async throws -> [String] {
        try await request(method: "GET", path: "/api/restrooms/descriptors")
    }

    public func checkCoordinates(_ payload: CoordsCheckRequest) async throws -> CoordsCheckResponse {
        try await request(method: "POST", path: "/api/restrooms/check-location", jsonBody: payload)
    }

    public func downloadRawData(from relativeOrAbsolute: String) async throws -> (Data, String?) {
        guard let url = resolveURL(relativeOrAbsolute) else {
            throw ArchiveAPIError.invalidURL(relativeOrAbsolute)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if let token = await tokenStore.readToken(), !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await perform(req)
        let mime = response.mimeType
        return (data, mime)
    }

    // MARK: - Annotations & UGC Reporting

    public func fetchAnnotations(slug: String) async throws -> [Annotation] {
        let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        return try await request(method: "GET", path: "/api/restrooms/\(encoded)/annotations")
    }

    public func createAnnotation(slug: String, payload: CreateAnnotationBody) async throws {
        let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        let _: OkResponse = try await request(
            method: "POST",
            path: "/api/restrooms/\(encoded)/annotations",
            jsonBody: payload
        )
    }

    public func deleteAnnotation(slug: String, annotationId: Int) async throws {
        let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        let _: OkResponse = try await request(
            method: "DELETE",
            path: "/api/restrooms/\(encoded)/annotations/\(annotationId)"
        )
    }

    public func reportAnnotation(slug: String, annotationId: Int, reason: String? = nil) async throws {
        let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        struct Body: Encodable { let reason: String? }
        let _: OkResponse = try await request(
            method: "POST",
            path: "/api/restrooms/\(encoded)/annotations/\(annotationId)/report",
            jsonBody: Body(reason: reason?.isEmpty == true ? nil : reason)
        )
    }

    public func reportRestroom(slug: String, reason: String? = nil) async throws {
        let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        struct Body: Encodable { let reason: String? }
        let _: OkResponse = try await request(
            method: "POST",
            path: "/api/restrooms/\(encoded)/report",
            jsonBody: Body(reason: reason?.isEmpty == true ? nil : reason)
        )
    }

    // MARK: - Submissions & Entry Management

    public func submitRestroom(_ form: SubmitRestroomForm) async throws -> SubmitRestroomResponse {
        let byteCount = Int64(form.fileData.count)
        if byteCount > UploadLimits.maxGlbBytes {
            throw ArchiveAPIError.fileTooLarge(byteCount)
        }
        if !UploadLimits.hasValidGLBMagic(form.fileData) {
            throw ArchiveAPIError.invalidGLBFile
        }

        var mp = MultipartFormData()
        mp.appendFile(
            name: "file",
            filename: form.fileName,
            mimeType: "model/gltf-binary",
            fileData: form.fileData
        )
        mp.appendField(name: "name", value: form.name)
        mp.appendField(name: "location", value: form.location)
        mp.appendField(name: "country", value: form.country)
        mp.appendField(name: "isoDate", value: form.isoDate)
        if !form.lat.isEmpty { mp.appendField(name: "lat", value: form.lat) }
        if !form.lng.isEmpty { mp.appendField(name: "lng", value: form.lng) }
        mp.appendField(name: "description", value: form.description.trimmingCharacters(in: .whitespacesAndNewlines))
        if !form.descriptors.isEmpty {
            let encoded = try JSONEncoder().encode(form.descriptors)
            if let str = String(data: encoded, encoding: .utf8) {
                mp.appendField(name: "descriptors", value: str)
            }
        }

        return try await requestMultipart(path: "/api/restrooms/submit", formData: mp, timeout: 180)
    }

    public func updateRestroom(slug: String, body: RestroomPatchBody) async throws {
        let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        let _: OkResponse = try await request(method: "PATCH", path: "/api/restrooms/\(encoded)", jsonBody: body)
    }

    public func deleteOrWithdrawRestroom(slug: String) async throws {
        let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        let _: OkResponse = try await request(method: "DELETE", path: "/api/restrooms/\(encoded)")
    }

    public func requestRestroomRemoval(slug: String, reason: String?) async throws {
        let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        struct Body: Encodable { let reason: String? }
        let trimmed = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        let _: OkResponse = try await request(
            method: "POST",
            path: "/api/restrooms/\(encoded)/request-removal",
            jsonBody: Body(reason: trimmed?.isEmpty == true ? nil : trimmed)
        )
    }

    public func uploadThumbnail(slug: String, imageDataUrl: String) async throws {
        let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        struct Body: Encodable { let imageData: String }
        let _: OkResponse = try await request(
            method: "POST",
            path: "/api/restrooms/\(encoded)/thumbnail",
            jsonBody: Body(imageData: imageDataUrl)
        )
    }

    // MARK: - Mobile Auth & Account

    public func signIn(email: String, password: String, deviceLabel: String? = "iOS App") async throws -> SessionUser {
        struct Body: Encodable {
            let email: String
            let password: String
            let deviceLabel: String?
        }
        let res: MobileAuthResponse = try await request(
            method: "POST",
            path: "/api/auth/mobile/signin",
            jsonBody: Body(email: email, password: password, deviceLabel: deviceLabel)
        )
        try await tokenStore.saveToken(res.token)
        return res.user
    }

    public func signUp(
        email: String,
        password: String,
        username: String,
        displayName: String?,
        deviceLabel: String? = "iOS App"
    ) async throws -> SessionUser {
        struct Body: Encodable {
            let email: String
            let password: String
            let username: String
            let displayName: String?
            let deviceLabel: String?
        }
        let cleanDisplay = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let res: MobileAuthResponse = try await request(
            method: "POST",
            path: "/api/auth/mobile/signup",
            jsonBody: Body(
                email: email,
                password: password,
                username: username,
                displayName: cleanDisplay?.isEmpty == true ? nil : cleanDisplay,
                deviceLabel: deviceLabel
            )
        )
        try await tokenStore.saveToken(res.token)
        return res.user
    }

    public func signOut() async {
        let _: OkResponse? = try? await request(method: "POST", path: "/api/auth/mobile/signout")
        try? await tokenStore.clearToken()
    }

    public func requestPasswordReset(email: String) async throws {
        struct Body: Encodable { let email: String }
        let _: OkResponse = try await request(
            method: "POST",
            path: "/api/auth/mobile/forgot-password",
            jsonBody: Body(email: email)
        )
    }

    public func fetchSession() async throws -> SessionUser? {
        let res: SessionResponse = try await request(method: "GET", path: "/api/me/session")
        return res.user
    }

    public func requestSubmissionAccess(agreements: [String] = SubmissionAgreements.all) async throws {
        struct Body: Encodable { let agreements: [String] }
        let _: OkResponse = try await request(
            method: "POST",
            path: "/api/auth/request-submission-access",
            jsonBody: Body(agreements: agreements)
        )
    }

    public func updateDisplayName(_ displayName: String) async throws {
        struct Body: Encodable { let displayName: String }
        let _: OkResponse = try await request(
            method: "PATCH",
            path: "/api/me",
            jsonBody: Body(displayName: displayName)
        )
    }

    public func updateEmail(newEmail: String, currentPassword: String) async throws {
        struct Body: Encodable {
            let email: String
            let currentPassword: String
        }
        let _: OkResponse = try await request(
            method: "PATCH",
            path: "/api/me/email",
            jsonBody: Body(email: newEmail, currentPassword: currentPassword)
        )
    }

    public func updatePassword(currentPassword: String, newPassword: String) async throws {
        struct Body: Encodable {
            let currentPassword: String
            let newPassword: String
        }
        let _: OkResponse = try await request(
            method: "PATCH",
            path: "/api/me/password",
            jsonBody: Body(currentPassword: currentPassword, newPassword: newPassword)
        )
    }

    public func deleteAccount(password: String) async throws {
        struct Body: Encodable { let password: String }
        let _: OkResponse = try await request(
            method: "POST",
            path: "/api/me/delete",
            jsonBody: Body(password: password)
        )
        try? await tokenStore.clearToken()
    }

    public func fetchMySubmissions() async throws -> [MySubmission] {
        try await request(method: "GET", path: "/api/me/submissions")
    }

    public func fetchMyAnnotations() async throws -> [MyAnnotation] {
        try await request(method: "GET", path: "/api/me/annotations")
    }

    public func fetchBlockedUsers() async throws -> [BlockedUser] {
        try await request(method: "GET", path: "/api/me/blocks")
    }

    public func blockUser(username: String) async throws {
        struct Body: Encodable { let username: String }
        let _: OkResponse = try await request(
            method: "POST",
            path: "/api/me/blocks",
            jsonBody: Body(username: username)
        )
    }

    public func unblockUser(username: String) async throws {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let _: OkResponse = try await request(method: "DELETE", path: "/api/me/blocks/\(encoded)")
    }

    public func sendContactMessage(_ form: ContactFormRequest) async throws {
        let _: OkResponse = try await request(
            method: "POST",
            path: "/api/contact/mobile",
            jsonBody: form
        )
    }

    // MARK: - Admin Notifications (Telegram)

    public func fetchNotifySettings() async throws -> NotifySettings {
        try await request(method: "GET", path: "/api/me/notifications")
    }

    public func updateNotifySettings(enabled: Bool) async throws {
        struct Body: Encodable { let enabled: Bool }
        let _: OkResponse = try await request(
            method: "PATCH",
            path: "/api/me/notifications",
            jsonBody: Body(enabled: enabled)
        )
    }

    public func startTelegramLink() async throws -> TelegramLink {
        try await request(method: "POST", path: "/api/me/notifications/telegram/link")
    }

    public func verifyTelegramLink() async throws {
        let _: OkResponse = try await request(method: "POST", path: "/api/me/notifications/telegram/verify")
    }

    public func disconnectTelegram() async throws {
        let _: OkResponse = try await request(method: "DELETE", path: "/api/me/notifications/telegram")
    }

    public func sendTestNotification() async throws {
        let _: OkResponse = try await request(method: "POST", path: "/api/me/notifications/test")
    }

    // MARK: - Admin Console Queues & Actions

    public func fetchAdminPendingRestrooms() async throws -> [PendingRestroom] {
        try await request(method: "GET", path: "/api/admin/restrooms")
    }

    public func publishRestroom(id: Int) async throws {
        let _: OkResponse = try await request(method: "POST", path: "/api/admin/restrooms/\(id)/publish")
    }

    public func rejectRestroom(id: Int, message: String?) async throws {
        struct Body: Encodable { let message: String? }
        let clean = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        let _: OkResponse = try await request(
            method: "POST",
            path: "/api/admin/restrooms/\(id)/reject",
            jsonBody: Body(message: clean?.isEmpty == true ? nil : clean)
        )
    }

    public func saveRestroomCrop(id: Int, cropResult: CropResult) async throws {
        let _: OkResponse = try await request(
            method: "POST",
            path: "/api/admin/restrooms/\(id)/crop",
            jsonBody: cropResult
        )
    }

    public func fetchAdminArchive() async throws -> [ArchiveEntry] {
        try await request(method: "GET", path: "/api/admin/restrooms/archive")
    }

    public func removeRestroom(id: Int, message: String? = nil) async throws {
        struct Body: Encodable { let message: String? }
        let clean = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        let _: OkResponse = try await request(
            method: "POST",
            path: "/api/admin/restrooms/\(id)/remove",
            jsonBody: Body(message: clean?.isEmpty == true ? nil : clean)
        )
    }

    public func fetchAdminRejected() async throws -> [RejectedSubmission] {
        try await request(method: "GET", path: "/api/admin/restrooms/rejected")
    }

    public func unrejectRestroom(id: Int) async throws {
        let _: OkResponse = try await request(method: "POST", path: "/api/admin/restrooms/\(id)/unreject")
    }

    public func fetchAdminRemovals() async throws -> [RemovalRequest] {
        try await request(method: "GET", path: "/api/admin/restrooms/removals")
    }

    public func dismissRemovalRequest(id: Int) async throws {
        let _: OkResponse = try await request(method: "POST", path: "/api/admin/restrooms/\(id)/dismiss-removal")
    }

    public func fetchAdminPendingUsers() async throws -> [PendingUser] {
        try await request(method: "GET", path: "/api/admin/users/pending")
    }

    public func approveUserUpgrade(id: Int) async throws {
        let _: OkResponse = try await request(method: "POST", path: "/api/admin/users/\(id)/approve")
    }

    public func rejectUserUpgrade(id: Int) async throws {
        let _: OkResponse = try await request(method: "POST", path: "/api/admin/users/\(id)/reject")
    }

    public func fetchAdminAccounts() async throws -> [AccountRow] {
        try await request(method: "GET", path: "/api/admin/users")
    }

    public func fetchAdminUserSubmissions(userId: Int) async throws -> [AccountSubmission] {
        try await request(method: "GET", path: "/api/admin/users/\(userId)/submissions")
    }

    public func fetchAdminUserAnnotations(userId: Int) async throws -> [AccountAnnotation] {
        try await request(method: "GET", path: "/api/admin/users/\(userId)/annotations")
    }

    public func adminUserAction(userId: Int, verb: String, message: String? = nil, days: Int? = nil) async throws {
        struct Body: Encodable {
            let message: String?
            let days: Int?
        }
        let clean = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        let _: OkResponse = try await request(
            method: "POST",
            path: "/api/admin/users/\(userId)/\(verb)",
            jsonBody: Body(message: clean?.isEmpty == true ? nil : clean, days: days)
        )
    }

    public func adminRenameUser(userId: Int, newUsername: String) async throws {
        struct Body: Encodable { let username: String }
        let _: OkResponse = try await request(
            method: "POST",
            path: "/api/admin/users/\(userId)/rename",
            jsonBody: Body(username: newUsername)
        )
    }

    public func adminDeleteUser(userId: Int) async throws {
        let _: OkResponse = try await request(method: "POST", path: "/api/admin/users/\(userId)/delete")
    }

    public func fetchAdminAnnotations() async throws -> [AdminAnnotation] {
        try await request(method: "GET", path: "/api/admin/annotations")
    }

    public func fetchAdminAnnotationReports() async throws -> [AnnotationReportItem] {
        try await request(method: "GET", path: "/api/admin/annotations/reports")
    }

    public func adminHideAnnotation(id: Int) async throws {
        let _: OkResponse = try await request(method: "POST", path: "/api/admin/annotations/\(id)/hide")
    }

    public func adminUnhideAnnotation(id: Int) async throws {
        let _: OkResponse = try await request(method: "POST", path: "/api/admin/annotations/\(id)/unhide")
    }

    public func adminDismissAnnotationReports(id: Int) async throws {
        let _: OkResponse = try await request(method: "POST", path: "/api/admin/annotations/\(id)/dismiss-reports")
    }

    public func fetchAdminAuditLog() async throws -> [AuditLogEntry] {
        try await request(method: "GET", path: "/api/admin/audit-log")
    }

    // MARK: - Transport Helpers

    private func request<Response: Decodable>(
        method: String,
        path: String
    ) async throws -> Response {
        guard let url = resolveURL(path) else {
            throw ArchiveAPIError.invalidURL(path)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await sendAndDecode(req)
    }

    private func request<Body: Encodable, Response: Decodable>(
        method: String,
        path: String,
        jsonBody: Body
    ) async throws -> Response {
        guard let url = resolveURL(path) else {
            throw ArchiveAPIError.invalidURL(path)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(jsonBody)
        return try await sendAndDecode(req)
    }

    private func requestMultipart<Response: Decodable>(
        path: String,
        formData: MultipartFormData,
        timeout: TimeInterval
    ) async throws -> Response {
        guard let url = resolveURL(path) else {
            throw ArchiveAPIError.invalidURL(path)
        }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(formData.contentTypeHeader, forHTTPHeaderField: "Content-Type")
        req.httpBody = formData.finalize()
        return try await sendAndDecode(req)
    }

    private func sendAndDecode<Response: Decodable>(_ baseRequest: URLRequest) async throws -> Response {
        var req = baseRequest
        if let token = await tokenStore.readToken(), !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await perform(req)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw ArchiveAPIError.decodingFailed(error.localizedDescription)
        }
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await session.data(for: request)
        } catch {
            throw ArchiveAPIError.networkFailure(error.localizedDescription)
        }
        guard let http = urlResponse as? HTTPURLResponse else {
            throw ArchiveAPIError.networkFailure("Invalid HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ArchiveAPIError.fromHTTPResponse(
                statusCode: http.statusCode,
                data: data,
                headers: http.allHeaderFields
            )
        }
        return (data, http)
    }
}

