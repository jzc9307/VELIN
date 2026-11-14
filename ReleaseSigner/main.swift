import Foundation
import CryptoKit
import Security

let service = "app.velin.release-signing", account = "updates-p256-v1"
func query() -> [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] }
func existing() throws -> P256.Signing.PrivateKey {
    var q = query(); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
    var data: CFTypeRef?; let status = SecItemCopyMatching(q as CFDictionary, &data)
    guard status == errSecSuccess, let bytes = data as? Data else { throw NSError(domain: "VELIN update signing", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Update-signing key is unavailable (\(status)). Unlock login Keychain or run setup on the original release Mac."]) }
    return try P256.Signing.PrivateKey(rawRepresentation: bytes)
}
do {
    let args = CommandLine.arguments
    guard args.count >= 2 else { throw CocoaError(.fileReadInvalidFileName) }
    if args[1] == "setup" {
        var q = query(); q[kSecReturnAttributes as String] = true
        let status = SecItemCopyMatching(q as CFDictionary, nil)
        if status == errSecItemNotFound {
            let key = P256.Signing.PrivateKey()
            var trusted: SecTrustedApplication?; guard SecTrustedApplicationCreateFromPath(args[0], &trusted) == errSecSuccess, let trusted else { throw CocoaError(.fileWriteNoPermission) }
            var access: SecAccess?; guard SecAccessCreate("VELIN update signing" as CFString, [trusted] as CFArray, &access) == errSecSuccess else { throw CocoaError(.fileWriteNoPermission) }
            var item = query(); item[kSecValueData as String] = key.rawRepresentation; item[kSecAttrLabel as String] = "VELIN Update Signing"; item[kSecAttrAccess as String] = access
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw NSError(domain: "VELIN signing", code: Int(added)) }
        } else if status != errSecSuccess { throw NSError(domain: "VELIN signing", code: Int(status)) }
        print(try existing().publicKey.x963Representation.base64EncodedString())
    } else if args[1] == "public" { print(try existing().publicKey.x963Representation.base64EncodedString()) }
    else if args[1] == "sign", args.count == 3 {
        let payload = try Data(contentsOf: URL(fileURLWithPath: args[2])); guard payload.count <= 65536 else { throw CocoaError(.fileReadTooLarge) }
        print(try existing().signature(for: payload).rawRepresentation.base64EncodedString())
    } else { throw CocoaError(.fileReadInvalidFileName) }
} catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
