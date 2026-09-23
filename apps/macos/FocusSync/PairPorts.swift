import CryptoKit
import Foundation

protocol PairForwarder: AnyObject {
    func registerDevice(
        baseURL: String,
        pairId: String,
        secret: String,
        sender: String,
        platform: String,
        token: String,
        e2ePublicKey: String?,
        apnsEnvironment: String
    ) async throws

    func createPair(
        baseURL: String,
        appKey: String,
        pairId: String,
        secretHash: String,
        sender: String,
        platform: String,
        token: String,
        e2ePublicKey: String?,
        apnsEnvironment: String
    ) async throws

    func listDevices(
        baseURL: String,
        pairId: String,
        secret: String
    ) async throws -> [ForwarderDevice]

    func postEnvelope(
        baseURL: String,
        pairId: String,
        secret: String,
        envelope: Data
    ) async throws

    func deletePair(baseURL: String, pairId: String, secret: String) async throws
}

extension ForwarderClient: PairForwarder {}

protocol PairStoring: AnyObject {
    func load() -> PersistedPair?
    func save(_ pair: PersistedPair)
    func clear()
}

extension PairStore: PairStoring {}

struct PairSecretsSource {
    var baseURL: String
    var appKey: String

    var canCreate: Bool { !baseURL.isEmpty && !appKey.isEmpty }

    static var live: PairSecretsSource {
        PairSecretsSource(baseURL: ForwarderSecrets.baseURL, appKey: ForwarderSecrets.appKey)
    }
}

struct UnpairContext {
    let pairId: String
    let pairSecret: String
    let forwarderURL: String
    let aesKey: SymmetricKey?
}
