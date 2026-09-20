import XCTest
@testable import DNDSync

final class DndStateFixtureTests: XCTestCase {
    func testGoldenFixtureDecodes() throws {
        let url = try XCTUnwrap(
            Bundle(for: DndStateFixtureTests.self).url(
                forResource: "dnd_state_v1",
                withExtension: "binpb"
            )
        )
        let data = try Data(contentsOf: url)
        let state = try Dndsync_V1_DndState(serializedBytes: data)
        XCTAssertEqual(state.version, 1)
        XCTAssertEqual(state.on, true)
        XCTAssertEqual(state.unixMs, 1_700_000_000_000)
        XCTAssertEqual(state.sender, "mac")
    }

    func testLengthPrefixedRoundTrip() throws {
        let payload = Data([1, 2, 3, 4])
        let framed = try LengthPrefixedFramer.frame(payload)
        let frames = try LengthPrefixedFramer.Accumulator().append(framed)
        XCTAssertEqual(frames, [payload])
    }

    func testDropsNonV1Payload() throws {
        var state = Dndsync_V1_DndState()
        state.version = 2
        state.on = true
        state.unixMs = 1
        state.sender = "mac"
        XCTAssertNil(DndStateFrames.decode(try state.serializedData()))
    }

    func testGoldenCloudEnvelopeDecodes() throws {
        let url = try XCTUnwrap(
            Bundle(for: DndStateFixtureTests.self).url(
                forResource: "cloud_envelope_v1",
                withExtension: "binpb"
            )
        )
        let data = try Data(contentsOf: url)
        let envelope = try Dndsync_V1_CloudEnvelope(serializedBytes: data)
        XCTAssertEqual(envelope.version, 1)
        XCTAssertEqual(envelope.pairID, "dndsync-dev")
        XCTAssertEqual(envelope.sender, "mac")
        let inner = try Dndsync_V1_DndState(serializedBytes: envelope.ciphertext)
        XCTAssertEqual(inner.version, 1)
        XCTAssertEqual(inner.on, true)
        XCTAssertEqual(inner.unixMs, 1_700_000_000_000)
        XCTAssertEqual(inner.sender, "mac")
    }

    func testDropsNonV1CloudEnvelope() throws {
        var envelope = Dndsync_V1_CloudEnvelope()
        envelope.version = 2
        envelope.pairID = "dndsync-dev"
        envelope.sender = "mac"
        envelope.ciphertext = Data()
        XCTAssertNil(CloudEnvelopeCodec.decode(try envelope.serializedData()))
    }

    func testPairControlVersionIsDroppedAsDndState() throws {
        let control = PairControlFrames.unpair(pairId: "dndsync-dev")
        let asState = try Dndsync_V1_DndState(serializedBytes: control.serializedData())
        XCTAssertEqual(asState.version, PairControlFrames.version)
        XCTAssertNil(DndStateFrames.decode(try control.serializedData()))
    }

    func testPairControlRoundTripUnpair() throws {
        let control = PairControlFrames.unpair(pairId: "dndsync-dev", unixMs: 1_700_000_000_000)
        let decoded = try XCTUnwrap(PairControlFrames.decode(try control.serializedData()))
        XCTAssertEqual(decoded.kind, .unpair)
        XCTAssertEqual(decoded.pairID, "dndsync-dev")
        XCTAssertEqual(decoded.unixMs, 1_700_000_000_000)
        XCTAssertTrue(PairControlFrames.matches(decoded, pairId: "dndsync-dev"))
        XCTAssertFalse(PairControlFrames.matches(decoded, pairId: "other"))
    }

    func testCloudEnvelopeCarriesPairControlKind() throws {
        let control = PairControlFrames.unpair(pairId: "dndsync-dev")
        let envelope = CloudEnvelopeCodec.make(
            pairId: "dndsync-dev",
            sender: "mac",
            ciphertext: try control.serializedData(),
            payloadKind: CloudEnvelopeCodec.payloadPairControl
        )
        XCTAssertEqual(envelope.payloadKind, CloudEnvelopeCodec.payloadPairControl)
        let decoded = try XCTUnwrap(PairControlFrames.decode(envelope.ciphertext))
        XCTAssertEqual(decoded.kind, .unpair)
    }

    func testInboundUnpairDoesNotNotifyPeer() {
        XCTAssertFalse(UnpairPolicy.shouldNotifyPeer(notifyPeer: false, joined: true))
        XCTAssertTrue(UnpairPolicy.shouldNotifyPeer(notifyPeer: true, joined: true))
        XCTAssertFalse(UnpairPolicy.shouldNotifyPeer(notifyPeer: true, joined: false))
    }

    func testE2ERoundTrip() throws {
        let alice = E2ECrypto.generateIdentity()
        let bob = E2ECrypto.generateIdentity()
        let aliceKey = try E2ECrypto.deriveKey(identity: alice, peerPublicRaw: bob.rawPublic)
        let bobKey = try E2ECrypto.deriveKey(identity: bob, peerPublicRaw: alice.rawPublic)
        let plain = Data("dnd-state".utf8)
        let sealed = try E2ECrypto.encrypt(plaintext: plain, key: aliceKey)
        let opened = try E2ECrypto.decrypt(combined: sealed, key: bobKey)
        XCTAssertEqual(opened, plain)
        XCTAssertNotEqual(sealed, plain)
    }

    func testPairPayloadJSONRoundTrip() throws {
        let payload = PairPayload(
            forwarderURL: "https://example.invalid",
            pairId: "dndsync-dev",
            pairSecret: "secret",
            macE2ePublicKey: "YQ==",
            macApnsToken: "abc"
        )
        let parsed = try PairPayload.parse(payload.jsonString())
        XCTAssertEqual(parsed, payload)
    }

    func testPairPayloadMissingMacDeviceName() throws {
        let json = """
        {"forwarder_url":"https://example.invalid","mac_apns_token":"abc","mac_e2e_public_key":"YQ==","pair_id":"dndsync-dev","pair_secret":"secret"}
        """
        let parsed = try PairPayload.parse(json)
        XCTAssertEqual(parsed.macDeviceName, nil)
        XCTAssertEqual(parsed.pairId, "dndsync-dev")
    }

    func testPairPayloadIncludesMacDeviceName() throws {
        let payload = PairPayload(
            forwarderURL: "https://example.invalid",
            pairId: "dndsync-dev",
            pairSecret: "secret",
            macE2ePublicKey: "YQ==",
            macApnsToken: "abc",
            macDeviceName: "Studio Mac"
        )
        let parsed = try PairPayload.parse(payload.jsonString())
        XCTAssertEqual(parsed.macDeviceName, "Studio Mac")
        XCTAssertEqual(parsed, payload)
    }
}
