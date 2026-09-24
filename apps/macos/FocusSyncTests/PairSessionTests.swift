import XCTest
@testable import FocusSync

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
        XCTAssertEqual(forwarder.apnsEnvironments, [PairSession.apnsEnvironment])
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

    func testUnjoinedUnauthorizedPeerReregistersSameCode() async {
        let forwarder = FakePairForwarder()
        let session = PairSession(
            forwarder: forwarder,
            store: InMemoryPairStore(),
            secrets: PairSecretsSource(baseURL: "https://example.invalid", appKey: "key"),
            apnsToken: { "token-hex" },
            deviceName: { "Test Mac" }
        )
        await session.create()
        let pairId = session.pairId
        let payload = session.pairPayloadJSON
        forwarder.created = false
        forwarder.listError = ForwarderClientError.httpStatus(401, "")

        await session.fetchPeer()

        XCTAssertTrue(forwarder.created)
        XCTAssertEqual(session.pairId, pairId)
        XCTAssertEqual(session.pairPayloadJSON, payload)
        XCTAssertFalse(session.pairingExpired)
        XCTAssertFalse(session.qrNeedsRetry)
        XCTAssertEqual(session.qrMessage, ProductCopy.waitingPhone)
    }

    func testCreateWithoutAppKeyShowsRetryNotInternetCall() async {
        let forwarder = FakePairForwarder()
        let session = PairSession(
            forwarder: forwarder,
            store: InMemoryPairStore(),
            secrets: PairSecretsSource(baseURL: "", appKey: ""),
            apnsToken: { "token-hex" },
            deviceName: { "Test Mac" }
        )

        await session.create()

        XCTAssertFalse(forwarder.created)
        XCTAssertTrue(session.qrNeedsRetry)
        XCTAssertEqual(session.qrMessage, ProductCopy.createPairFailed)
        XCTAssertFalse(session.createdPairForCurrentId)
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
        for _ in 0..<50 where !forwarder.deleted {
            await Task.yield()
        }

        XCTAssertFalse(session.joined)
        XCTAssertTrue(forwarder.deleted)
    }

    func testUnpairNotifiesPeerWhenJoined() async {
        let session = joinedSession(forwarder: FakePairForwarder(), store: InMemoryPairStore())
        var notified: UnpairContext?
        session.onNotifyPeerUnpair = { notified = $0 }

        session.unpair(notifyPeer: true)
        for _ in 0..<50 where notified == nil {
            await Task.yield()
        }

        XCTAssertEqual(notified?.pairId, "dndsync-abc")
        XCTAssertEqual(notified?.pairSecret, "secret")
        XCTAssertFalse(session.joined)
    }

    func testUnauthorizedPairCheckWhileJoinedUnpairs() async {
        let forwarder = FakePairForwarder()
        let session = joinedSession(forwarder: forwarder, store: InMemoryPairStore())
        XCTAssertTrue(session.joined)

        forwarder.error = ForwarderClientError.httpStatus(401, "")
        await session.refreshPairOrUnpair()

        XCTAssertFalse(session.joined)
    }

    func testPairCheckLeavesJoinedOnSuccess() async {
        let forwarder = FakePairForwarder()
        let session = joinedSession(forwarder: forwarder, store: InMemoryPairStore())
        forwarder.devices = [
            ForwarderDevice(sender: LanConstants.senderAndroid, e2ePublicKey: "YQ==")
        ]
        await session.refreshPairOrUnpair()
        XCTAssertTrue(session.joined)
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

    func testRegisterDeviceSkipsUnchangedToken() async {
        let forwarder = FakePairForwarder()
        let store = InMemoryPairStore()
        var token = "token-hex"
        let session = joinedSession(forwarder: forwarder, store: store, apnsToken: { token })

        await session.registerDevice()
        await session.registerDevice()
        XCTAssertEqual(forwarder.registeredTokens, ["token-hex"])

        token = "token-new"
        await session.registerDevice()
        XCTAssertEqual(forwarder.registeredTokens, ["token-hex", "token-new"])

        // The fingerprint survives a relaunch.
        let relaunched = PairSession(
            forwarder: forwarder,
            store: store,
            secrets: PairSecretsSource(baseURL: "https://example.invalid", appKey: "key"),
            apnsToken: { token }
        )
        relaunched.restore()
        await relaunched.registerDevice()
        XCTAssertEqual(forwarder.registeredTokens.count, 2)
    }

    func testCreateCountsAsRegistration() async {
        let forwarder = FakePairForwarder()
        let session = PairSession(
            forwarder: forwarder,
            store: InMemoryPairStore(),
            secrets: PairSecretsSource(baseURL: "https://example.invalid", appKey: "key"),
            apnsToken: { "token-hex" },
            deviceName: { "Test Mac" }
        )
        await session.registerDevice()
        XCTAssertTrue(forwarder.registeredTokens.isEmpty, "no server pair yet")

        await session.create()
        await session.registerDevice()
        XCTAssertTrue(forwarder.registeredTokens.isEmpty)
    }

    func testPairCheckIsThrottled() async {
        let forwarder = FakePairForwarder()
        var now = Date(timeIntervalSince1970: 1_000)
        let session = joinedSession(
            forwarder: forwarder,
            store: InMemoryPairStore(),
            now: { now }
        )

        await session.refreshPairOrUnpair()
        now += 60
        await session.refreshPairOrUnpair()
        XCTAssertEqual(forwarder.listCount, 1)

        now += PairSession.pairCheckInterval
        await session.refreshPairOrUnpair()
        XCTAssertEqual(forwarder.listCount, 2)
    }

    func testUnpairDoesNotCreateNextPair() async {
        let forwarder = FakePairForwarder()
        let session = joinedSession(forwarder: forwarder, store: InMemoryPairStore())

        session.unpair(notifyPeer: false)
        for _ in 0..<50 where !forwarder.deleted {
            await Task.yield()
        }

        XCTAssertTrue(forwarder.deleted)
        XCTAssertEqual(forwarder.createCount, 0)
        XCTAssertFalse(session.createdPairForCurrentId)

        await session.create()
        XCTAssertEqual(forwarder.createCount, 1)
    }

    func testPeerPollStopsWhenNoLongerShown() async {
        let forwarder = FakePairForwarder()
        let session = PairSession(
            forwarder: forwarder,
            store: InMemoryPairStore(),
            secrets: PairSecretsSource(baseURL: "https://example.invalid", appKey: "key"),
            apnsToken: { "token-hex" },
            deviceName: { "Test Mac" }
        )
        await session.create()
        let shown = false

        session.startPeerPoll(shouldContinue: { shown })
        for _ in 0..<50 {
            await Task.yield()
        }

        XCTAssertEqual(forwarder.listCount, 0)
    }

    private func joinedSession(
        forwarder: FakePairForwarder,
        store: InMemoryPairStore,
        apnsToken: @escaping () -> String = { "token-hex" },
        now: @escaping () -> Date = Date.init
    ) -> PairSession {
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
            apnsToken: apnsToken,
            now: now
        )
        session.restore()
        return session
    }
}
