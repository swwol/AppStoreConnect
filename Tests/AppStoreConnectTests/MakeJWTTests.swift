import Crypto
import Foundation
import Testing

@testable import AppStoreConnect

@Suite("MakeJWTTests")
struct MakeJWTTests {
    @Test func generateAToken() throws {
    let keyId = "123456789Z"
    let issuerId = "12345678-ABCD-EFGH-IJKL-MNOPQRSTUVWXz"
    let privateKey = P256.Signing.PrivateKey()
    let publicKey = privateKey.publicKey

    let token = try makeJWT(
        keyId: keyId, issuerId: issuerId, key: privateKey.pemRepresentation)

    // Token starts with base64url-encoded header beginning with "eyJ"
    #expect(token.hasPrefix("eyJ"))

    // Token has three dot-separated parts (header.payload.signature)
    let parts = token.split(separator: ".")
    #expect(parts.count == 3)

    // Verify the signature
    let signingInput = Data(("\(parts[0]).\(parts[1])").utf8)
    let signatureData = Data(base64URLEncoded: String(parts[2]))!
    let signature = try P256.Signing.ECDSASignature(rawRepresentation: signatureData)
    #expect(publicKey.isValidSignature(signature, for: signingInput))

    // Verify the payload contains the correct issuer
    let payloadData = Data(base64URLEncoded: String(parts[1]))!
    let payload = try JSONDecoder().decode(JWTPayload.self, from: payloadData)
    #expect(payload.iss == issuerId)
    }
}

private struct JWTPayload: Decodable {
    let iss: String
    let exp: Int
    let aud: String
}

private extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        self.init(base64Encoded: base64)
    }
}
