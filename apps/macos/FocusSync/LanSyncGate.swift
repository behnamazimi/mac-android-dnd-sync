import Foundation

final class LanSyncGate {
    var onOriginate: ((Dndsync_V1_DndState) -> Void)?
    var onApplyRemote: ((Bool) -> Void)?

    private let sender: String
    private let nowMs: () -> Int64
    private var lastAppliedUnixMs: Int64 = 0
    private var lastAppliedOn: Bool?
    private var applyingRemote = false
    private var echoUntilMs: Int64 = 0

    init(sender: String, nowMs: @escaping () -> Int64 = {
        Int64(Date().timeIntervalSince1970 * 1000)
    }) {
        self.sender = sender
        self.nowMs = nowMs
    }

    func noteObserverEvent() {
        applyingRemote = false
    }

    func reset() {
        lastAppliedUnixMs = 0
        lastAppliedOn = nil
        applyingRemote = false
        echoUntilMs = 0
    }

    func onLocalChange(on: Bool) {
        let now = nowMs()
        if now >= echoUntilMs {
            applyingRemote = false
        }
        if applyingRemote || now < echoUntilMs {
            return
        }
        // Shortcuts can take longer than the 1s echo window to flip Focus.
        // The observer that then fires is the apply we just did, not a new
        // user action — originating it would log a duplicate "by this Mac"
        // row and bounce the same on/off back to the phone.
        if lastAppliedOn == on {
            return
        }
        let msg = DndStateFrames.make(on: on, unixMs: now, sender: sender)
        lastAppliedUnixMs = msg.unixMs
        lastAppliedOn = on
        onOriginate?(msg)
    }

    func onRemote(_ msg: Dndsync_V1_DndState) -> Bool {
        if msg.version != LanConstants.protoVersion {
            return false
        }
        if msg.unixMs <= lastAppliedUnixMs {
            return false
        }
        lastAppliedUnixMs = msg.unixMs
        lastAppliedOn = msg.on
        applyingRemote = true
        echoUntilMs = nowMs() + LanConstants.echoWindowMs
        onApplyRemote?(msg.on)
        return true
    }
}
