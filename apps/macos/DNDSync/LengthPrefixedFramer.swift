import Foundation

enum LengthPrefixedFramer {
    enum FramerError: Error {
        case payloadTooLarge(Int)
    }

    static func frame(_ payload: Data) throws -> Data {
        guard payload.count <= LanConstants.maxFrameBytes else {
            throw FramerError.payloadTooLarge(payload.count)
        }
        var framed = Data(count: 4 + payload.count)
        framed.withUnsafeMutableBytes { raw in
            raw.storeBytes(of: UInt32(payload.count).bigEndian, as: UInt32.self)
        }
        framed.replaceSubrange(4..<framed.count, with: payload)
        return framed
    }

    final class Accumulator {
        private var buffer = Data()

        func append(_ chunk: Data) throws -> [Data] {
            buffer.append(chunk)
            var frames: [Data] = []
            while buffer.count >= 4 {
                let length = Self.readUInt32BE(buffer)
                if length > UInt32(LanConstants.maxFrameBytes) {
                    throw FramerError.payloadTooLarge(Int(length))
                }
                let total = 4 + Int(length)
                if buffer.count < total {
                    break
                }
                frames.append(buffer.subdata(in: 4..<total))
                buffer.removeSubrange(0..<total)
            }
            return frames
        }

        private static func readUInt32BE(_ data: Data) -> UInt32 {
            var value: UInt32 = 0
            _ = withUnsafeMutableBytes(of: &value) { dest in
                data.prefix(4).copyBytes(to: dest)
            }
            return UInt32(bigEndian: value)
        }
    }
}

enum PairControlFrames {
    static let version: UInt32 = 2

    static func unpair(
        pairId: String,
        unixMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) -> Dndsync_V1_PairControl {
        var control = Dndsync_V1_PairControl()
        control.version = version
        control.kind = .unpair
        control.pairID = pairId
        control.unixMs = unixMs
        return control
    }

    static func decode(_ payload: Data) -> Dndsync_V1_PairControl? {
        guard let control = try? Dndsync_V1_PairControl(serializedBytes: payload) else {
            return nil
        }
        guard control.version == version, control.kind == .unpair else {
            return nil
        }
        return control
    }

    static func matches(_ control: Dndsync_V1_PairControl, pairId: String) -> Bool {
        control.pairID.isEmpty || control.pairID == pairId
    }
}

enum UnpairPolicy {
    static func shouldNotifyPeer(notifyPeer: Bool, joined: Bool) -> Bool {
        notifyPeer && joined
    }
}

enum DndStateFrames {
    static func encode(_ state: Dndsync_V1_DndState) throws -> Data {
        try LengthPrefixedFramer.frame(state.serializedData())
    }

    static func decode(_ payload: Data) -> Dndsync_V1_DndState? {
        guard let state = try? Dndsync_V1_DndState(serializedBytes: payload) else {
            return nil
        }
        guard state.version == LanConstants.protoVersion else {
            return nil
        }
        return state
    }

    static func make(on: Bool, unixMs: Int64, sender: String) -> Dndsync_V1_DndState {
        var state = Dndsync_V1_DndState()
        state.version = LanConstants.protoVersion
        state.on = on
        state.unixMs = unixMs
        state.sender = sender
        return state
    }
}
