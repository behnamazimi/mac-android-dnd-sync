import Foundation

/// Originate and apply DndState. Owns echo suppression and last-write-wins
/// across LAN and the wake-and-pull CloudEnvelope.
@MainActor
final class SyncSession {
    var lanAdvertising = false
    var lanBrowsing = false
    var lanConnected = false
    var lastInboundText = "Last inbound: —"
    var lastLanErrorText = "Last LAN error: —"
    var lastEnvelopePostText = "Last envelope POST: —"

    var onStateChange: (() -> Void)?
    var onApplyRemote: ((Bool) -> Void)?

    private let lan: SyncLan
    private let cloud: SyncCloud
    private let pair: SyncPairing
    private let gate: LanSyncGate

    init(
        lan: SyncLan,
        cloud: SyncCloud,
        pair: SyncPairing,
        nowMs: @escaping () -> Int64 = {
            Int64(Date().timeIntervalSince1970 * 1000)
        }
    ) {
        self.lan = lan
        self.cloud = cloud
        self.pair = pair
        self.gate = LanSyncGate(sender: LanConstants.senderMac, nowMs: nowMs)
        wire()
    }

    func onLocalFocusChange(on: Bool) {
        gate.noteObserverEvent()
        gate.onLocalChange(on: on)
    }

    func onInboundState(_ state: Dndsync_V1_DndState, viaLan: Bool) {
        lastInboundText =
            "Last inbound: on=\(state.on) unix_ms=\(state.unixMs) sender=\(state.sender)"
        publish()
        if gate.onRemote(state) {
            debug("apply on=\(state.on) unix_ms=\(state.unixMs) viaLan=\(viaLan)")
            pair.persistLastSync(
                unixMs: state.unixMs,
                on: state.on,
                sender: state.sender,
                viaLan: viaLan
            )
        } else {
            debug("drop on=\(state.on) unix_ms=\(state.unixMs) viaLan=\(viaLan)")
        }
    }

    func onInboundUnpair(_ control: Dndsync_V1_PairControl) {
        pair.handleInboundUnpair(control)
    }

    func onInboundEnvelope(_ envelope: Dndsync_V1_CloudEnvelope) {
        debug("cloud envelope kind=\(envelope.payloadKind) sender=\(envelope.sender)")
        let plaintext: Data
        if pair.joined {
            if let opened = pair.open(envelope.ciphertext) {
                plaintext = opened
            } else if envelope.payloadKind == CloudEnvelopeCodec.payloadPairControl {
                debug("cloud drop pair-control decrypt")
                return
            } else {
                debug("cloud drop decrypt")
                pair.noteCloudError("decrypt failed")
                return
            }
        } else {
            plaintext = envelope.ciphertext
        }
        if envelope.payloadKind == CloudEnvelopeCodec.payloadPairControl
            || PairControlFrames.decode(plaintext) != nil
        {
            if let control = PairControlFrames.decode(plaintext) {
                onInboundUnpair(control)
            }
            return
        }
        guard let state = DndStateFrames.decode(plaintext) else {
            debug("cloud drop invalid DndState")
            pair.noteCloudError("invalid inner DndState")
            return
        }
        onInboundState(state, viaLan: false)
    }

    private func debug(_ message: String) {
        #if DEBUG
        print("[DEBUG] \(message)")
        #endif
    }

    func sendUnpair(_ context: UnpairContext) {
        guard !context.pairId.isEmpty else {
            return
        }
        let control = PairControlFrames.unpair(pairId: context.pairId)
        lan.sendUnpairNow(control)
        guard !context.pairSecret.isEmpty, !context.forwarderURL.isEmpty else {
            return
        }
        Task {
            await self.postUnpairAndDelete(context: context, control: control)
        }
    }

    func setPairId(_ pairId: String) {
        lan.setPairId(pairId)
    }

    func startLANIfJoined() {
        if pair.joined {
            lan.start()
        }
    }

    func stopLAN() {
        lan.stop()
        gate.reset()
    }

    private func wire() {
        gate.onOriginate = { [weak self] state in
            guard let self, self.pair.joined else { return }
            self.postEnvelope(state)
            self.pair.persistLastSync(
                unixMs: state.unixMs,
                on: state.on,
                sender: state.sender,
                viaLan: false
            )
        }
        gate.onApplyRemote = { [weak self] on in
            self?.onApplyRemote?(on)
        }
        lan.onUiState = { [weak self] snapshot in
            Task { @MainActor in
                guard let self else { return }
                self.lanAdvertising = snapshot.advertising
                self.lanBrowsing = snapshot.browsing
                self.lanConnected = snapshot.connected
                if let error = snapshot.lastError {
                    self.lastLanErrorText = "Last LAN error: \(error)"
                } else if snapshot.connected {
                    self.lastLanErrorText = "Last LAN error: —"
                }
                self.publish()
            }
        }
        lan.onInbound = { [weak self] state in
            Task { @MainActor in
                self?.onInboundState(state, viaLan: true)
            }
        }
        lan.onInboundUnpair = { [weak self] control in
            Task { @MainActor in
                self?.onInboundUnpair(control)
            }
        }
    }

    private func postEnvelope(_ state: Dndsync_V1_DndState) {
        Task {
            do {
                let inner = try state.serializedData()
                let ciphertext = try pair.seal(inner)
                let envelope = CloudEnvelopeCodec.make(
                    pairId: pair.pairId,
                    sender: LanConstants.senderMac,
                    ciphertext: ciphertext
                )
                let body = try CloudEnvelopeCodec.encode(envelope)
                try await cloud.postEnvelope(
                    baseURL: pair.forwarderURL,
                    pairId: pair.pairId,
                    secret: pair.pairSecret,
                    envelope: body
                )
                lastEnvelopePostText = "Last envelope POST: 204"
                pair.noteCloudSuccess()
                publish()
            } catch {
                if isUnauthorized(error) {
                    pair.noteCloudUnauthorized()
                } else {
                    pair.noteCloudError(error.localizedDescription)
                }
                publish()
            }
        }
    }

    private func postUnpairAndDelete(context: UnpairContext, control: Dndsync_V1_PairControl) async {
        do {
            let inner = try control.serializedData()
            let ciphertext: Data
            if let aesKey = context.aesKey {
                ciphertext = try E2ECrypto.encrypt(plaintext: inner, key: aesKey)
            } else {
                ciphertext = inner
            }
            let envelope = CloudEnvelopeCodec.make(
                pairId: context.pairId,
                sender: LanConstants.senderMac,
                ciphertext: ciphertext,
                payloadKind: CloudEnvelopeCodec.payloadPairControl
            )
            let body = try CloudEnvelopeCodec.encode(envelope)
            try await cloud.postEnvelope(
                baseURL: context.forwarderURL,
                pairId: context.pairId,
                secret: context.pairSecret,
                envelope: body
            )
        } catch {
        }
        do {
            try await cloud.deletePair(
                baseURL: context.forwarderURL,
                pairId: context.pairId,
                secret: context.pairSecret
            )
        } catch {
        }
    }

    private func isUnauthorized(_ error: Error) -> Bool {
        if case ForwarderClientError.httpStatus(401, _) = error {
            return true
        }
        return error.localizedDescription.contains("HTTP 401")
    }

    private func publish() {
        onStateChange?()
    }
}
