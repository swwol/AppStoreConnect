import Crypto
import Foundation

private struct Header: Encodable {
    let alg: String
    let kid: String
    let typ: String
}

private struct Payload: Encodable {
    let iss: String
    let exp: Int
    let aud: String
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Creates a signed JWT for App Store Connect API authentication.
/// - Parameters:
///   - keyId: The key ID from App Store Connect.
///   - issuerId: The issuer ID from App Store Connect.
///   - key: The PEM-encoded ES256 private key.
/// - Returns: A signed JWT string.
public func makeJWT(keyId: String, issuerId: String, key: String) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys

    let header = Header(alg: "ES256", kid: keyId, typ: "JWT")
    let headerBase64 = try encoder.encode(header).base64URLEncodedString()

    let expiryEpochSeconds = Int(Date().timeIntervalSince1970) + 900
    let payload = Payload(iss: issuerId, exp: expiryEpochSeconds, aud: "appstoreconnect-v1")
    let payloadBase64 = try encoder.encode(payload).base64URLEncodedString()

    let signingInput = "\(headerBase64).\(payloadBase64)"

    let privateKey = try P256.Signing.PrivateKey(pemRepresentation: key)
    let signature = try privateKey.signature(for: Data(signingInput.utf8))

    let signatureBase64 = signature.rawRepresentation.base64URLEncodedString()

    return "\(signingInput).\(signatureBase64)"
}
