import Foundation

enum CloudEnvelopeCodec {
    static let protoVersion: UInt32 = 1
    static let maxPushBytes = 4 * 1024
    static let payloadDndState: UInt32 = 0
    static let payloadPairControl: UInt32 = 1

    static func make(
        pairId: String,
        sender: String,
        ciphertext: Data,
        payloadKind: UInt32 = payloadDndState
    ) -> Dndsync_V1_CloudEnvelope {
        var envelope = Dndsync_V1_CloudEnvelope()
        envelope.version = protoVersion
        envelope.pairID = pairId
        envelope.sender = sender
        envelope.ciphertext = ciphertext
        envelope.payloadKind = payloadKind
        return envelope
    }

    static func encode(_ envelope: Dndsync_V1_CloudEnvelope) throws -> Data {
        try envelope.serializedData()
    }

    static func decode(_ data: Data) -> Dndsync_V1_CloudEnvelope? {
        guard let envelope = try? Dndsync_V1_CloudEnvelope(serializedBytes: data) else {
            return nil
        }
        guard envelope.version == protoVersion else {
            return nil
        }
        return envelope
    }

    static func decodeBase64(_ value: String) -> Dndsync_V1_CloudEnvelope? {
        guard let data = Data(base64Encoded: value) else {
            return nil
        }
        return decode(data)
    }
}
