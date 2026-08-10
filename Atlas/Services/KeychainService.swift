import Foundation
import Security

/// Secure storage for gateway tokens and API keys.
///
/// Secrets are stored **exclusively** in the iOS Keychain — never in
/// `UserDefaults`, never in SwiftData, never in plaintext on disk. Items use
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` so they are available to
/// background tasks after first unlock but never sync off-device.
struct KeychainService: Sendable {
    private let service: String

    init(service: String = "com.atlas.gateway") {
        self.service = service
    }

    enum KeychainError: Error, Equatable {
        case unexpectedStatus(OSStatus)
        case dataConversionFailed
    }

    /// Stores (or replaces) the token for a gateway identified by `id`.
    func storeToken(_ token: String, for id: UUID) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        let account = id.uuidString

        // Replace any existing item atomically.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Retrieves the token for a gateway, or `nil` if none is stored.
    func token(for id: UUID) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let token = String(data: data, encoding: .utf8) else {
                throw KeychainError.dataConversionFailed
            }
            return token
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Removes the token for a gateway (used on disconnect / re-pair).
    func deleteToken(for id: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
