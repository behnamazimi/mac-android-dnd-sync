import Foundation
@testable import FocusSync

final class InMemoryPairStore: PairStoring {
    var stored: PersistedPair?

    func load() -> PersistedPair? { stored }
    func save(_ pair: PersistedPair) { stored = pair }
    func clear() { stored = nil }
}

final class FakePairForwarder: PairForwarder {
    var devices: [ForwarderDevice] = []
    var created = false
    var deleted = false
    var envelopes: [Data] = []
    var registeredTokens: [String] = []
    var apnsEnvironments: [String] = []
    var error: Error?
    /// Applied only to `listDevices`, so a 401 while checking the peer can
    /// still be followed by a successful `createPair`.
    var listError: Error?

    func registerDevice(
        baseURL: String,
        pairId: String,
        secret: String,
        sender: String,
        platform: String,
        token: String,
        e2ePublicKey: String?,
        apnsEnvironment: String
    ) async throws {
        if let error { throw error }
        registeredTokens.append(token)
        apnsEnvironments.append(apnsEnvironment)
    }

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
    ) async throws {
        if let error { throw error }
        created = true
        apnsEnvironments.append(apnsEnvironment)
    }

    func listDevices(
        baseURL: String,
        pairId: String,
        secret: String
    ) async throws -> [ForwarderDevice] {
        if let listError { throw listError }
        if let error { throw error }
        return devices
    }

    func postEnvelope(
        baseURL: String,
        pairId: String,
        secret: String,
        envelope: Data
    ) async throws {
        if let error { throw error }
        envelopes.append(envelope)
    }

    func deletePair(baseURL: String, pairId: String, secret: String) async throws {
        if let error { throw error }
        deleted = true
    }
}
