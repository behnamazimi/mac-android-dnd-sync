import XCTest
@testable import DNDSync

@MainActor
final class PairSessionTests: XCTestCase {
    func testCreateThenAndroidDeviceJoins() async {
        let forwarder = FakePairForwarder()
        let store = InMemoryPairStore()
        let phone = E2ECrypto.generateIdentity()
        let session = PairSession(
            forwarder: forwarder,
            store: store,
            secrets: PairSecretsSource(baseURL: "https://example.invalid", appKey: "key"),
            apnsToken: { "token-hex" },
            deviceName: { "Test Mac" }
        )

        await session.create()
        XCTAssertTrue(forwarder.created)
        XCTAssertFalse(session.joined)
        XCTAssertTrue(session.createdPairForCurrentId)

        forwarder.devices = [
            ForwarderDevice(sender: LanConstants.senderAndroid, e2ePublicKey: phone.rawPublic.base64EncodedString())
        ]
        await session.fetchPeer()

        XCTAssertTrue(session.joined)
        XCTAssertEqual(session.pairStatusText, "Pair: E2E ready")
        XCTAssertNotNil(store.stored?.peerPublicKeyB64)
    }

    func testStartPeerPollJoinsWithoutManualRefresh() async {
        let forwarder = FakePairForwarder()
        let store = InMemoryPairStore()
        let phone = E2ECrypto.generateIdentity()
        let session = PairSession(
            forwarder: forwarder,
            store: store,
            secrets: PairSecretsSource(baseURL: "https://example.invalid", appKey: "key"),
            apnsToken: { "token-hex" },
            deviceName: { "Test Mac" }
        )
        await session.create()
        XCTAssertFalse(session.joined)

        forwarder.devices = [
            ForwarderDevice(sender: LanConstants.senderAndroid, e2ePublicKey: phone.rawPublic.base64EncodedString())
        ]
        session.startPeerPoll(shouldContinue: { true })

        // The poll's first iteration calls `fetchPeer()` before its first
        // sleep, so this joins without a manual "Check again" tap — give
        // the detached Task a chance to run rather than sleeping for real.
        for _ in 0..<50 where !session.joined {
            await Task.yield()
        }

        XCTAssertTrue(session.joined)
        session.stopPeerPoll()
    }

    func testUnpairClearsJoined() async {
        let forwarder = FakePairForwarder()
        let store = InMemoryPairStore()
        let session = joinedSession(forwarder: forwarder, store: store)

        XCTAssertTrue(session.joined)
        session.unpair(notifyPeer: false)

        XCTAssertFalse(session.joined)
    }

    func testRestoreFromStore() {
        let mac = E2ECrypto.generateIdentity()
        let phone = E2ECrypto.generateIdentity()
        let key = try? E2ECrypto.deriveKey(identity: mac, peerPublicRaw: phone.rawPublic)
        XCTAssertNotNil(key)

        let store = InMemoryPairStore()
        store.stored = PersistedPair(
            pairId: "dndsync-abc",
            pairSecret: "secret",
            forwarderURL: "https://example.invalid",
            privateKeyB64: mac.rawPrivate.base64EncodedString(),
            publicKeyB64: mac.rawPublic.base64EncodedString(),
            peerPublicKeyB64: phone.rawPublic.base64EncodedString(),
            lastSyncUnixMs: 42,
            lastSyncOn: true,
            lastSyncSender: "android",
            lastSyncViaLan: true
        )
        let session = PairSession(
            forwarder: FakePairForwarder(),
            store: store,
            secrets: PairSecretsSource(baseURL: "https://example.invalid", appKey: "key"),
            apnsToken: { "token-hex" }
        )
        session.restore()

        XCTAssertTrue(session.joined)
        XCTAssertEqual(session.pairId, "dndsync-abc")
        XCTAssertEqual(session.lastSyncUnixMs, 42)
        XCTAssertTrue(session.lastSyncViaLan)
    }

    func testPersistLastSyncSurvivesRestoreAcrossSessions() {
        let store = InMemoryPairStore()
        let session = joinedSession(forwarder: FakePairForwarder(), store: store)

        session.persistLastSync(unixMs: 100, on: true, sender: "mac", viaLan: true)
        session.persistLastSync(unixMs: 200, on: false, sender: "android", viaLan: false)

        XCTAssertEqual(session.recentActivity.map(\.unixMs), [200, 100])

        // Simulate quitting and relaunching: a fresh session restores from
        // the same persisted store (this is what regressed: the trail used
        // to live only on `FocusHarnessModel` and never reached the store).
        let relaunched = PairSession(
            forwarder: FakePairForwarder(),
            store: store,
            secrets: PairSecretsSource(baseURL: "https://example.invalid", appKey: "key"),
            apnsToken: { "token-hex" }
        )
        relaunched.restore()

        XCTAssertEqual(relaunched.recentActivity.map(\.unixMs), [200, 100])
        XCTAssertEqual(relaunched.recentActivity.first?.on, false)
        XCTAssertEqual(relaunched.recentActivity.first?.sender, "android")
    }

    func testUnpairClearsRecentActivity() {
        let store = InMemoryPairStore()
        let session = joinedSession(forwarder: FakePairForwarder(), store: store)
        session.persistLastSync(unixMs: 100, on: true, sender: "mac", viaLan: true)
        XCTAssertFalse(session.recentActivity.isEmpty)

        session.unpair(notifyPeer: false)

        XCTAssertTrue(session.recentActivity.isEmpty)
    }

    func testRestoreSeedsRecentActivityFromLegacyLastSyncOnly() {
        let mac = E2ECrypto.generateIdentity()
        let phone = E2ECrypto.generateIdentity()
        let store = InMemoryPairStore()
        store.stored = PersistedPair(
            pairId: "dndsync-abc",
            pairSecret: "secret",
            forwarderURL: "https://example.invalid",
            privateKeyB64: mac.rawPrivate.base64EncodedString(),
            publicKeyB64: mac.rawPublic.base64EncodedString(),
            peerPublicKeyB64: phone.rawPublic.base64EncodedString(),
            lastSyncUnixMs: 42,
            lastSyncOn: true,
            lastSyncSender: "android",
            lastSyncViaLan: true
            // recentActivity defaults to `[]` — a pair persisted before this
            // trail existed.
        )
        let session = PairSession(
            forwarder: FakePairForwarder(),
            store: store,
            secrets: PairSecretsSource(baseURL: "https://example.invalid", appKey: "key"),
            apnsToken: { "token-hex" }
        )
        session.restore()

        XCTAssertEqual(session.recentActivity.map(\.unixMs), [42])
        XCTAssertEqual(session.recentActivity.first?.on, true)
        XCTAssertEqual(session.recentActivity.first?.sender, "android")
    }

    func testSealOpenRoundTripWhenJoined() async throws {
        let forwarder = FakePairForwarder()
        let session = joinedSession(forwarder: forwarder, store: InMemoryPairStore())
        let plain = Data("hello".utf8)
        let sealed = try session.seal(plain)
        XCTAssertNotEqual(sealed, plain)
        XCTAssertEqual(session.open(sealed), plain)
    }

    private func joinedSession(forwarder: FakePairForwarder, store: InMemoryPairStore) -> PairSession {
        let mac = E2ECrypto.generateIdentity()
        let phone = E2ECrypto.generateIdentity()
        store.stored = PersistedPair(
            pairId: "dndsync-abc",
            pairSecret: "secret",
            forwarderURL: "https://example.invalid",
            privateKeyB64: mac.rawPrivate.base64EncodedString(),
            publicKeyB64: mac.rawPublic.base64EncodedString(),
            peerPublicKeyB64: phone.rawPublic.base64EncodedString()
        )
        let session = PairSession(
            forwarder: forwarder,
            store: store,
            secrets: PairSecretsSource(baseURL: "https://example.invalid", appKey: "key"),
            apnsToken: { "token-hex" }
        )
        session.restore()
        return session
    }
}
