import Foundation
import Security

@main struct CredentialProbe {
    static func main() {
        let connection = NSXPCConnection(serviceName: CredentialIdentity.broker)
        connection.remoteObjectInterface = NSXPCInterface(with: VelinCredentialProtocol.self)
        if let requirement = CredentialIdentity.peerRequirement(CredentialIdentity.broker) { connection.setCodeSigningRequirement(requirement) }
        connection.resume()
        var replied = false
        var status = errSecNotAvailable
        let proxy = connection.synchronousRemoteObjectProxyWithErrorHandler { _ in status = errSecNotAvailable } as? VelinCredentialProtocol
        proxy?.access("contains", account: UUID().uuidString, value: nil) { _, result in replied = true; status = result }
        print("replied=\(replied) status=\(status)")
        connection.invalidate()
        let allowed = Bundle.main.bundleIdentifier == CredentialIdentity.app
        exit((allowed ? (replied && status == errSecItemNotFound) : (!replied && status == errSecNotAvailable)) ? 0 : 1)
    }
}
