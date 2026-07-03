import Foundation
import Security

/// The one Keychain boundary for the package: generic-password items
/// addressed by a fixed service plus a per-item account. AuthClient (token
/// JSON) and ModelClient (API keys) both persist through this — services and
/// accounts are theirs to choose and must stay stable across releases.
struct KeychainStore: Sendable {
    let service: String

    func read(account: String) -> String? {
        readData(account: account).flatMap { String(data: $0, encoding: .utf8) }
    }

    func readData(account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return data
    }

    /// Replaces the item; nil removes it.
    func write(_ value: String?, account: String) throws(KeychainStoreError) {
        try writeData(value.map { Data($0.utf8) }, account: account)
    }

    /// Replaces the item; nil removes it.
    func writeData(_ data: Data?, account: String) throws(KeychainStoreError) {
        let base = baseQuery(account: account)
        SecItemDelete(base as CFDictionary)
        guard let data else { return }
        var attributes = base
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStoreError.writeFailed(status: Int(status))
        }
    }

    func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum KeychainStoreError: Error, Equatable {
    case writeFailed(status: Int)
}
