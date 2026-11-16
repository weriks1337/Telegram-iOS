import Foundation
import Security
import CryptoKit

public enum KeyStoreError: Error {
    case keychainStatus(OSStatus)
    case invalidKey
}

/// Stores a single 256-bit encryption key in this device's Keychain.
public struct KeychainKeyStore: Sendable {
    private let service: String
    private let account: String

    public init(service: String = "app.ayugram.ios", account: String = "history-encryption-key") {
        self.service = service
        self.account = account
    }

    public func loadOrCreateKey() throws -> SymmetricKey {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, data.count == 32 {
            return SymmetricKey(data: data)
        }
        guard status == errSecItemNotFound else { throw KeyStoreError.keychainStatus(status) }

        let generated = SymmetricKey(size: .bits256)
        let keyData = generated.withUnsafeBytes { Data($0) }
        query.removeAll()
        query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus == errSecDuplicateItem { return try loadOrCreateKey() }
        guard addStatus == errSecSuccess else { throw KeyStoreError.keychainStatus(addStatus) }
        return generated
    }
}
