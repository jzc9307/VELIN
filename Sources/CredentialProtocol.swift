import Foundation
import Security
import CryptoKit

@objc protocol VelinCredentialProtocol {
    func access(_ operation: String, account: String, value: String?, reply: @escaping (String?, Int32) -> Void)
}

enum CredentialIdentity {
    static let app = "app.velin.assistant"
    static let broker = "app.velin.assistant.credentials"
    static func peerRequirement(_ identifier: String) -> String? {
        var code: SecCode?, staticCode: SecStaticCode?, information: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let dict = information as? [String: Any], let certificate = (dict[kSecCodeInfoCertificates as String] as? [SecCertificate])?.first else { return nil }
        let hash = Insecure.SHA1.hash(data: SecCertificateCopyData(certificate) as Data).map { String(format: "%02x", $0) }.joined()
        return "identifier \"\(identifier)\" and certificate leaf = H\"\(hash)\""
    }
}
