import Foundation
import Security

public protocol TokenStoring: Sendable {
    func readToken() async -> String?
    func saveToken(_ token: String) async throws
    func clearToken() async throws
}

public actor InMemoryTokenStore: TokenStoring {
    private var token: String?

    public init(initialToken: String? = nil) {
        self.token = initialToken
    }

    public func readToken() async -> String? {
        token
    }

    public func saveToken(_ token: String) async throws {
        self.token = token
    }

    public func clearToken() async throws {
        self.token = nil
    }
}

public actor KeychainTokenStore: TokenStoring {
    public enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
    }

    private let service: String
    private let account: String

    public init(
        service: String = "com.restroomarchive.app",
        account: String = "mobile_bearer_token"
    ) {
        self.service = service
        self.account = account
    }

    public func readToken() async -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public func saveToken(_ token: String) async throws {
        let encoded = Data(token.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: encoded
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            throw KeychainError.unexpectedStatus(updateStatus)
        }

        var insertQuery = baseQuery
        insertQuery[kSecValueData as String] = encoded
        insertQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(insertQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    public func clearToken() async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

