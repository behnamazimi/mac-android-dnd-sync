import CryptoKit
import Foundation

enum E2ECryptoError: Error {
    case invalidKey
    case encryptFailed
    case decryptFailed
}

enum E2ECrypto {
    static let hkdfInfo = Data("dndsync-e2e-v1".utf8)

    struct Identity {
        let privateKey: Curve25519.KeyAgreement.PrivateKey

        var rawPrivate: Data { privateKey.rawRepresentation }
        var rawPublic: Data { privateKey.publicKey.rawRepresentation }
    }

    static func generateIdentity() -> Identity {
        Identity(privateKey: Curve25519.KeyAgreement.PrivateKey())
    }

    static func identity(privateRaw: Data) throws -> Identity {
        do {
            return Identity(
                privateKey: try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateRaw)
            )
        } catch {
            throw E2ECryptoError.invalidKey
        }
    }

    static func deriveKey(identity: Identity, peerPublicRaw: Data) throws -> SymmetricKey {
        let peer: Curve25519.KeyAgreement.PublicKey
        do {
            peer = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicRaw)
        } catch {
            throw E2ECryptoError.invalidKey
        }
        let shared = try identity.privateKey.sharedSecretFromKeyAgreement(with: peer)
        return shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: hkdfInfo,
            outputByteCount: 32
        )
    }

    static func encrypt(plaintext: Data, key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw E2ECryptoError.encryptFailed
        }
        return combined
    }

    static func decrypt(combined: Data, key: SymmetricKey) throws -> Data {
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw E2ECryptoError.decryptFailed
        }
    }

    static func sha256Hex(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            bytes = (0..<count).map { _ in UInt8.random(in: 0...255) }
        }
        return Data(bytes)
    }
}
