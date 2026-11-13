import Foundation
import Security
import OSLog

enum RawSecretStore {
    static let service = "app.velin.assistant.providers"
    static func contains(_ id: UUID) -> Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: id.uuidString, kSecMatchLimit as String: kSecMatchLimitOne]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
    static func read(_ id: UUID) -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: id.uuidString, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            Logger(subsystem: "app.velin.assistant", category: "Keychain").error("Credential read status: \(status, privacy: .public)")
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static func write(_ value: String, id: UUID) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: id.uuidString]
        if value.isEmpty { let status = SecItemDelete(query as CFDictionary); guard status == errSecSuccess || status == errSecItemNotFound else { throw NSError(domain: "app.velin.keychain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Keychain could not remove this key (\(status))."]) }; return }
        let values: [String: Any] = [kSecValueData as String: Data(value.utf8), kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound { status = SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil) }
        guard status == errSecSuccess else { throw NSError(domain: "app.velin.keychain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Keychain could not save this key (\(status))."]) }
    }
}
