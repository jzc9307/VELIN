import Foundation
import Security

final class CredentialService: NSObject, VelinCredentialProtocol {
    func access(_ operation: String, account: String, value: String?, reply: @escaping (String?, Int32) -> Void) {
        guard let id = UUID(uuidString: account) else { reply(nil, errSecParam); return }
        switch operation {
        case "contains": reply(nil, RawSecretStore.contains(id) ? errSecSuccess : errSecItemNotFound)
        case "read":
            let secret = RawSecretStore.read(id)
            reply(secret.isEmpty ? nil : secret, secret.isEmpty ? errSecItemNotFound : errSecSuccess)
        case "write":
            guard let value else { reply(nil, errSecParam); return }
            do { try RawSecretStore.write(value, id: id); reply(nil, errSecSuccess) }
            catch { reply(nil, OSStatus((error as NSError).code)) }
        default: reply(nil, errSecParam)
        }
    }
}
final class CredentialDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier == getuid(),
              let requirement = CredentialIdentity.peerRequirement(CredentialIdentity.app) else { return false }
        connection.setCodeSigningRequirement(requirement)
        connection.exportedInterface = NSXPCInterface(with: VelinCredentialProtocol.self)
        connection.exportedObject = CredentialService()
        connection.resume(); return true
    }
}
let listener = NSXPCListener.service()
let delegate = CredentialDelegate()
listener.delegate = delegate
listener.resume()
