import Foundation
import Security

/// The stable embedded service owns Keychain access across main-app rebuilds.
enum SecretStore {
    static let service = RawSecretStore.service
    private static var cache: [UUID: String] = [:]
    private static var connection: NSXPCConnection?
    private static var usesBroker: Bool { Bundle.main.bundleIdentifier == CredentialIdentity.app }
    private static func call(_ operation: String, id: UUID, value: String? = nil) -> (String?, OSStatus) {
        if connection == nil {
            guard let requirement = CredentialIdentity.peerRequirement(CredentialIdentity.broker) else { return (nil, errSecAuthFailed) }
            let service = NSXPCConnection(serviceName: CredentialIdentity.broker)
            service.remoteObjectInterface = NSXPCInterface(with: VelinCredentialProtocol.self)
            service.setCodeSigningRequirement(requirement)
            service.resume(); connection = service
        }
        var result: String?, status = errSecNotAvailable
        let proxy = connection?.synchronousRemoteObjectProxyWithErrorHandler { _ in status = errSecNotAvailable } as? VelinCredentialProtocol
        proxy?.access(operation, account: id.uuidString, value: value) { result = $0; status = $1 }
        if status == errSecNotAvailable { connection?.invalidate(); connection = nil }
        return (result, status)
    }
    static func contains(_ id: UUID) -> Bool {
        if !usesBroker { return RawSecretStore.contains(id) }
        return cache[id] != nil || call("contains", id: id).1 == errSecSuccess
    }
    static func read(_ id: UUID) -> String {
        if !usesBroker { return RawSecretStore.read(id) }
        if let saved = cache[id] { return saved }
        let (value, status) = call("read", id: id)
        guard status == errSecSuccess, let value, !value.isEmpty else { return "" }
        cache[id] = value; return value
    }
    static func write(_ value: String, id: UUID) throws {
        if !usesBroker { try RawSecretStore.write(value, id: id); return }
        let status = call("write", id: id, value: value).1
        guard status == errSecSuccess else { throw VelinError.message("Keychain could not save this key (\(status)).") }
        if value.isEmpty { cache.removeValue(forKey: id) } else { cache[id] = value }
    }
}
