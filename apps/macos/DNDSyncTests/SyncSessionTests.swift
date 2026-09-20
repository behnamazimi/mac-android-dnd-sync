import XCTest
@testable import DNDSync

@MainActor
final class SyncSessionTests: XCTestCase {
    func testLocalChangeWhileJoinedSendsLanAndCloud() async {
        let lan = InMemorySyncLan()
        let cloud = InMemorySyncCloud()
        let pair = FakeSyncPairing()
        pair.joined = true
        var now: Int64 = 1_000
        let session = SyncSession(lan: lan, cloud: cloud, pair: pair, nowMs: { now })

        session.onLocalFocusChange(on: true)
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(lan.sent.count, 1)
        XCTAssertEqual(lan.sent[0].on, true)
        XCTAssertEqual(lan.sent[0].sender, LanConstants.senderMac)
        XCTAssertEqual(cloud.posts.count, 1)
        XCTAssertEqual(pair.lastSync?.on, true)
        XCTAssertEqual(pair.lastSync?.viaLan, false)
        _ = now
    }

    func testRemoteApplyIsEchoSuppressed() {
        let lan = InMemorySyncLan()
        let pair = FakeSyncPairing()
        pair.joined = true
        var now: Int64 = 5_000
        var applied: [Bool] = []
        let session = SyncSession(
            lan: lan,
            cloud: InMemorySyncCloud(),
            pair: pair,
            nowMs: { now }
        )
        session.onApplyRemote = { applied.append($0) }

        var remote = DndStateFrames.make(on: true, unixMs: 5_000, sender: LanConstants.senderAndroid)
        session.onInboundState(remote, viaLan: true)
        XCTAssertEqual(applied, [true])
        XCTAssertTrue(lan.sent.isEmpty)

        now = 5_500
        session.onLocalFocusChange(on: true)
        XCTAssertTrue(lan.sent.isEmpty)

        now = 6_500
        session.onLocalFocusChange(on: false)
        XCTAssertEqual(lan.sent.count, 1)
        XCTAssertEqual(lan.sent[0].on, false)
        _ = remote
    }

    func testLateFocusObserverAfterRemoteDoesNotPersistMacOrigin() {
        let lan = InMemorySyncLan()
        let pair = FakeSyncPairing()
        pair.joined = true
        var now: Int64 = 5_000
        let session = SyncSession(
            lan: lan,
            cloud: InMemorySyncCloud(),
            pair: pair,
            nowMs: { now }
        )

        session.onInboundState(
            DndStateFrames.make(on: true, unixMs: 5_000, sender: LanConstants.senderAndroid),
            viaLan: true
        )
        XCTAssertEqual(pair.lastSync?.sender, LanConstants.senderAndroid)
        XCTAssertTrue(lan.sent.isEmpty)

        // Shortcuts often finish after the 1s echo window. The Focus observer
        // then reports the same on/off the phone just sent — that must not
        // become a second "by this Mac" activity row.
        now = 8_000
        session.onLocalFocusChange(on: true)
        XCTAssertTrue(lan.sent.isEmpty)
        XCTAssertEqual(pair.lastSync?.sender, LanConstants.senderAndroid)
        XCTAssertEqual(pair.lastSync?.on, true)

        session.onLocalFocusChange(on: false)
        XCTAssertEqual(lan.sent.count, 1)
        XCTAssertEqual(lan.sent[0].on, false)
        XCTAssertEqual(lan.sent[0].sender, LanConstants.senderMac)
        XCTAssertEqual(pair.lastSync?.sender, LanConstants.senderMac)
    }

    func testOlderUnixMsDropped() {
        let pair = FakeSyncPairing()
        pair.joined = true
        var applied: [Bool] = []
        let session = SyncSession(
            lan: InMemorySyncLan(),
            cloud: InMemorySyncCloud(),
            pair: pair,
            nowMs: { 10_000 }
        )
        session.onApplyRemote = { applied.append($0) }

        session.onInboundState(
            DndStateFrames.make(on: true, unixMs: 8_000, sender: LanConstants.senderAndroid),
            viaLan: true
        )
        session.onInboundState(
            DndStateFrames.make(on: false, unixMs: 7_000, sender: LanConstants.senderAndroid),
            viaLan: true
        )

        XCTAssertEqual(applied, [true])
        XCTAssertEqual(pair.lastSync?.unixMs, 8_000)
    }

    func testNotJoinedDoesNotOriginate() {
        let lan = InMemorySyncLan()
        let pair = FakeSyncPairing()
        pair.joined = false
        let session = SyncSession(
            lan: lan,
            cloud: InMemorySyncCloud(),
            pair: pair,
            nowMs: { 1_000 }
        )

        session.onLocalFocusChange(on: true)
        XCTAssertTrue(lan.sent.isEmpty)
        XCTAssertNil(pair.lastSync)
    }

    func testUnpairFrameClearsPair() {
        let pair = FakeSyncPairing()
        pair.joined = true
        let session = SyncSession(
            lan: InMemorySyncLan(),
            cloud: InMemorySyncCloud(),
            pair: pair
        )

        session.onInboundUnpair(PairControlFrames.unpair(pairId: "dndsync-test"))
        XCTAssertTrue(pair.unpaired)
        XCTAssertFalse(pair.joined)
    }
}

final class LanSyncGateTests: XCTestCase {
    func testEchoWindowSuppressesLocalChange() {
        var now: Int64 = 1_000
        let gate = LanSyncGate(sender: "mac", nowMs: { now })
        var originated: [Bool] = []
        var applied: [Bool] = []
        gate.onOriginate = { originated.append($0.on) }
        gate.onApplyRemote = { applied.append($0) }

        XCTAssertTrue(gate.onRemote(DndStateFrames.make(on: true, unixMs: 1_000, sender: "android")))
        XCTAssertEqual(applied, [true])

        now = 1_500
        gate.noteObserverEvent()
        gate.onLocalChange(on: true)
        XCTAssertTrue(originated.isEmpty)

        now = 2_100
        gate.onLocalChange(on: false)
        XCTAssertEqual(originated, [false])
    }

    func testLateFocusObserverMatchingRemoteDoesNotOriginate() {
        var now: Int64 = 1_000
        let gate = LanSyncGate(sender: "mac", nowMs: { now })
        var originated: [Bool] = []
        gate.onOriginate = { originated.append($0.on) }

        XCTAssertTrue(gate.onRemote(DndStateFrames.make(on: true, unixMs: 1_000, sender: "android")))

        now = 4_000
        gate.noteObserverEvent()
        gate.onLocalChange(on: true)
        XCTAssertTrue(originated.isEmpty)

        gate.onLocalChange(on: false)
        XCTAssertEqual(originated, [false])
    }

    func testResetAllowsSameOnToOriginateAfterUnpair() {
        var now: Int64 = 1_000
        let gate = LanSyncGate(sender: "mac", nowMs: { now })
        var originated: [Bool] = []
        gate.onOriginate = { originated.append($0.on) }

        XCTAssertTrue(gate.onRemote(DndStateFrames.make(on: true, unixMs: 1_000, sender: "android")))
        now = 4_000
        gate.reset()
        gate.onLocalChange(on: true)
        XCTAssertEqual(originated, [true])
    }

    func testLastWriteWinsDropsOlder() {
        let gate = LanSyncGate(sender: "mac", nowMs: { 9_000 })
        var applied: [Bool] = []
        gate.onApplyRemote = { applied.append($0) }

        XCTAssertTrue(gate.onRemote(DndStateFrames.make(on: true, unixMs: 8_000, sender: "android")))
        XCTAssertFalse(gate.onRemote(DndStateFrames.make(on: false, unixMs: 7_000, sender: "android")))
        XCTAssertEqual(applied, [true])
    }
}
