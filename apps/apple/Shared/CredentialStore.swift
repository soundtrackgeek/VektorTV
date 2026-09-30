import Foundation
import Security

enum CredentialStore {
    private static var key: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.soundtrackgeek.vektortv.connection",
         kSecAttrAccount as String: "provider"]
    }
    static func load() throws -> ProviderConnection? {
        var query = key
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw AppFailure(message: "Your saved account could not be read from Keychain.")
        }
        do { return try JSONDecoder().decode(ProviderConnection.self, from: data) }
        catch { throw AppFailure(message: "Your saved account could not be restored. Reconnect in Settings.") }
    }
    static func save(_ connection: ProviderConnection) throws {
        let data = try JSONEncoder().encode(connection)
        let updates = [kSecValueData as String: data]
        var status = SecItemUpdate(key as CFDictionary, updates as CFDictionary)
        if status == errSecItemNotFound {
            var item = key
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw AppFailure(message: "The account connected, but Keychain could not save it. Please retry.") }
    }
    static func delete() throws {
        let status = SecItemDelete(key as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppFailure(message: "The saved account could not be removed from Keychain.")
        }
    }
}
