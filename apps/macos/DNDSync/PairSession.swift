import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import CryptoKit
import Foundation

/// Create, restore, QR, join, unpair. Owns E2E keys. Callers see `joined`,
/// never `aesKey`.
@MainActor
final class PairSession {
    private static let pairIdPrefix = "dndsync-"
    private static let pairIdByteCount = 8
    private static let secretByteCount = 32
    private static let platform = "apns"
    static let apnsEnvironment: String = {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }()
    private static let pollSeconds: Double = 15
    private static let qrScale: CGFloat = 10
    private static let qrCorrection = "M"

    var joined: Bool { aesKey != nil }
    var pairId = ""
    var pairSecret = ""
    var forwarderURL = ""
    var pairPayloadJSON = ""
    var qrImage: NSImage?
    var pairStatusText = "Pair: not created"
    var qrMessage: String?
    var qrNeedsRetry = false
    var pairingExpired = false
    var createdPairForCurrentId = false
    var lastSyncUnixMs: Int64 = 0
    var lastSyncOn = false
    var lastSyncSender = ""
    var lastSyncViaLan = false
    /// Home's "Recent activity" trail (max 5, newest first). Persisted
    /// alongside `lastSync*` so it survives quitting and relaunching the app.
    var recentActivity: [SyncEvent] = []
    var lastRegisterText = "Last register: —"
    var lastCloudErrorText = "Last cloud error: —"
    var forwarderURLText = "Forwarder: —"

    var e2ePublicKeyB64: String { identity.rawPublic.base64EncodedString() }

    var onNotifyPeerUnpair: ((UnpairContext) -> Void)?
    var onJoined: (() -> Void)?
    var onCleared: (() -> Void)?
    var onPairIdChange: ((String) -> Void)?
    var onStateChange: (() -> Void)?

    private let forwarder: PairForwarder
    private let store: PairStoring
    private let secrets: PairSecretsSource
    private let apnsToken: () -> String
    private let deviceName: () -> String

    private var identity = E2ECrypto.generateIdentity()
    private var peerPublicKey: Data?
    private var aesKey: SymmetricKey?
    private var pollTask: Task<Void, Never>?
    private var createPairInFlight = false

    init(
        forwarder: PairForwarder,
        store: PairStoring,
        secrets: PairSecretsSource = .live,
        apnsToken: @escaping () -> String,
        deviceName: @escaping () -> String = { Host.current().localizedName ?? "Mac" }
    ) {
        self.forwarder = forwarder
        self.store = store
        self.secrets = secrets
        self.apnsToken = apnsToken
        self.deviceName = deviceName
    }

    func restore() {
        if let saved = store.load(),
           let privateRaw = Data(base64Encoded: saved.privateKeyB64),
           let restored = try? E2ECrypto.identity(privateRaw: privateRaw)
        {
            pairId = saved.pairId
            pairSecret = saved.pairSecret
            forwarderURL = saved.forwarderURL
            identity = restored
            if let peerB64 = saved.peerPublicKeyB64,
               let peer = Data(base64Encoded: peerB64)
            {
                peerPublicKey = peer
                aesKey = try? E2ECrypto.deriveKey(identity: identity, peerPublicRaw: peer)
            }
            pairStatusText = aesKey == nil ? "Pair: waiting for Android join" : "Pair: E2E ready"
            createdPairForCurrentId = true
            lastSyncUnixMs = saved.lastSyncUnixMs
            lastSyncOn = saved.lastSyncOn
            lastSyncSender = saved.lastSyncSender
            lastSyncViaLan = saved.lastSyncViaLan
            recentActivity = saved.recentActivity.map {
                SyncEvent(unixMs: $0.unixMs, on: $0.on, sender: $0.sender)
            }
            if recentActivity.isEmpty {
                // Back-compat: a pair persisted before this trail existed
                // only kept the single last sync. `appending` already turns
                // `unixMs == 0` into an empty trail, so this is a no-op for
                // a pair that has never synced.
                recentActivity = RecentActivity.appending(
                    SyncEvent(unixMs: saved.lastSyncUnixMs, on: saved.lastSyncOn, sender: saved.lastSyncSender),
                    to: []
                )
            }
        } else {
            pairId = ""
            pairSecret = ""
            forwarderURL = secrets.baseURL
            pairStatusText = secrets.canCreate
                ? "Pair: not created"
                : "Pair: missing ForwarderSecrets.local.swift"
        }
        if forwarderURL.isEmpty {
            forwarderURLText = "Forwarder: missing ForwarderSecrets.local.swift"
        } else {
            forwarderURLText = "Forwarder: \(forwarderURL)"
        }
        onPairIdChange?(pairId)
        refreshPayload()
        publish()
    }

    func create() async {
        if createPairInFlight || createdPairForCurrentId {
            return
        }
        createPairInFlight = true
        defer { createPairInFlight = false }
        qrNeedsRetry = false
        guard secrets.canCreate else {
            lastCloudErrorText = "Last cloud error: missing app key in ForwarderSecrets.local.swift"
            qrMessage = ProductCopy.createPairFailed
            qrNeedsRetry = true
            publish()
            return
        }
        let token = apnsToken()
        if token.isEmpty {
            qrMessage = ProductCopy.waitingApns
            publish()
            return
        }
        if pairSecret.isEmpty {
            pairSecret = hex(E2ECrypto.randomBytes(Self.secretByteCount))
        }
        if pairId.isEmpty {
            pairId = Self.pairIdPrefix + hex(E2ECrypto.randomBytes(Self.pairIdByteCount))
        }
        forwarderURL = secrets.baseURL
        qrMessage = nil
        do {
            try await forwarder.createPair(
                baseURL: forwarderURL,
                appKey: secrets.appKey,
                pairId: pairId,
                secretHash: E2ECrypto.sha256Hex(pairSecret),
                sender: LanConstants.senderMac,
                platform: Self.platform,
                token: token,
                e2ePublicKey: e2ePublicKeyB64,
                apnsEnvironment: Self.apnsEnvironment
            )
            persist()
            onPairIdChange?(pairId)
            createdPairForCurrentId = true
            refreshPayload()
            lastRegisterText = "Last register: create-pair 201"
            pairStatusText = "Pair: created. Waiting for the phone."
            lastCloudErrorText = "Last cloud error: —"
            qrMessage = ProductCopy.waitingPhone
            publish()
        } catch {
            lastRegisterText = "Last register: create-pair failed"
            lastCloudErrorText = "Last cloud error: \(error.localizedDescription)"
            qrMessage = ProductCopy.createPairFailed
            qrNeedsRetry = true
            publish()
        }
    }

    func retryCreate() async {
        createdPairForCurrentId = false
        await create()
    }

    func registerDevice() async {
        let token = apnsToken()
        guard !forwarderURL.isEmpty, !pairSecret.isEmpty, !token.isEmpty else {
            if secrets.baseURL.isEmpty || pairSecret.isEmpty {
                lastRegisterText = "Last register: missing ForwarderSecrets.local.swift"
                publish()
            }
            return
        }
        do {
            try await forwarder.registerDevice(
                baseURL: forwarderURL,
                pairId: pairId,
                secret: pairSecret,
                sender: LanConstants.senderMac,
                platform: Self.platform,
                token: token,
                e2ePublicKey: e2ePublicKeyB64,
                apnsEnvironment: Self.apnsEnvironment
            )
            lastRegisterText = "Last register: 204"
            lastCloudErrorText = "Last cloud error: —"
            publish()
        } catch {
            lastRegisterText = "Last register: failed"
            lastCloudErrorText = "Last cloud error: \(error.localizedDescription)"
            if isUnauthorized(error) {
                autoUnpairIfExpired()
            }
            publish()
        }
    }

    func fetchPeer() async {
        guard !forwarderURL.isEmpty, !pairSecret.isEmpty else {
            return
        }
        do {
            let devices = try await forwarder.listDevices(
                baseURL: forwarderURL,
                pairId: pairId,
                secret: pairSecret
            )
            guard let android = devices.first(where: { $0.sender == LanConstants.senderAndroid }),
                  let peer = Data(base64Encoded: android.e2ePublicKey),
                  !peer.isEmpty
            else {
                qrMessage = ProductCopy.waitingPhone
                publish()
                return
            }
            peerPublicKey = peer
            aesKey = try E2ECrypto.deriveKey(identity: identity, peerPublicRaw: peer)
            persist()
            pairStatusText = "Pair: E2E ready"
            lastCloudErrorText = "Last cloud error: —"
            qrMessage = nil
            pairingExpired = false
            publish()
            onJoined?()
        } catch {
            if isUnauthorized(error) {
                lastCloudErrorText = "Last cloud error: \(ProductCopy.pairingExpired)"
                if aesKey != nil {
                    autoUnpairIfExpired()
                } else {
                    pairingExpired = true
                    qrMessage = ProductCopy.pairingExpired
                }
            } else {
                lastCloudErrorText = "Last cloud error: \(error.localizedDescription)"
                qrMessage = error.localizedDescription
            }
            publish()
        }
    }

    func unpair(notifyPeer: Bool) {
        if UnpairPolicy.shouldNotifyPeer(notifyPeer: notifyPeer, joined: joined) {
            onNotifyPeerUnpair?(
                UnpairContext(
                    pairId: pairId,
                    pairSecret: pairSecret,
                    forwarderURL: forwarderURL,
                    aesKey: aesKey
                )
            )
        }
        onCleared?()
        store.clear()
        identity = E2ECrypto.generateIdentity()
        peerPublicKey = nil
        aesKey = nil
        pairId = Self.pairIdPrefix + hex(E2ECrypto.randomBytes(Self.pairIdByteCount))
        pairSecret = hex(E2ECrypto.randomBytes(Self.secretByteCount))
        pairPayloadJSON = ""
        qrImage = nil
        createdPairForCurrentId = false
        pairStatusText = "Pair: cleared. Create a new pair."
        lastCloudErrorText = "Last cloud error: —"
        pairingExpired = false
        lastSyncUnixMs = 0
        lastSyncOn = false
        lastSyncSender = ""
        lastSyncViaLan = false
        recentActivity = []
        stopPeerPoll()
        onPairIdChange?(pairId)
        publish()
        Task {
            await create()
        }
    }

    func handleInboundUnpair(_ control: Dndsync_V1_PairControl) {
        guard joined else { return }
        guard PairControlFrames.matches(control, pairId: pairId) else { return }
        unpair(notifyPeer: false)
    }

    /// The phone deletes the pair on unpair. Silent APNs to a menu-bar extra
    /// often never arrives, and LAN may not be up. A 401 here is the signal.
    func refreshPairOrUnpair() async {
        guard joined, !forwarderURL.isEmpty, !pairSecret.isEmpty, !pairId.isEmpty else {
            return
        }
        do {
            _ = try await forwarder.listDevices(
                baseURL: forwarderURL,
                pairId: pairId,
                secret: pairSecret
            )
        } catch {
            if isUnauthorized(error) {
                autoUnpairIfExpired()
            }
        }
    }

    func startPeerPoll(shouldContinue: @escaping () -> Bool) {
        if pollTask != nil { return }
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled, shouldContinue(), self.aesKey == nil {
                await self.fetchPeer()
                try? await Task.sleep(for: .seconds(Self.pollSeconds))
            }
            self?.pollTask = nil
        }
    }

    func stopPeerPoll() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refreshPayload() {
        let token = apnsToken()
        guard createdPairForCurrentId,
              !forwarderURL.isEmpty,
              !pairSecret.isEmpty,
              !pairId.isEmpty,
              !token.isEmpty
        else {
            pairPayloadJSON = ""
            qrImage = nil
            return
        }
        let payload = PairPayload(
            forwarderURL: forwarderURL,
            pairId: pairId,
            pairSecret: pairSecret,
            macE2ePublicKey: e2ePublicKeyB64,
            macApnsToken: token,
            macDeviceName: deviceName()
        )
        if let json = try? payload.jsonString() {
            pairPayloadJSON = json
            qrImage = Self.makeQRImage(json)
        }
    }

    func persistLastSync(unixMs: Int64, on: Bool, sender: String, viaLan: Bool) {
        lastSyncUnixMs = unixMs
        lastSyncOn = on
        lastSyncSender = sender
        lastSyncViaLan = viaLan
        recentActivity = RecentActivity.appending(
            SyncEvent(unixMs: unixMs, on: on, sender: sender),
            to: recentActivity
        )
        persist()
        publish()
    }

    func noteCloudUnauthorized() {
        lastCloudErrorText = "Last cloud error: \(ProductCopy.pairingExpired)"
        autoUnpairIfExpired()
        publish()
    }

    func noteCloudError(_ message: String) {
        lastCloudErrorText = "Last cloud error: \(message)"
        publish()
    }

    func noteCloudSuccess() {
        lastCloudErrorText = "Last cloud error: —"
        pairingExpired = false
        publish()
    }

    func seal(_ plaintext: Data) throws -> Data {
        if let aesKey {
            return try E2ECrypto.encrypt(plaintext: plaintext, key: aesKey)
        }
        return plaintext
    }

    func open(_ ciphertext: Data) -> Data? {
        guard let aesKey else {
            return ciphertext
        }
        if let opened = try? E2ECrypto.decrypt(combined: ciphertext, key: aesKey) {
            return opened
        }
        if DndStateFrames.decode(ciphertext) != nil {
            return ciphertext
        }
        return nil
    }

    private func persist() {
        store.save(
            PersistedPair(
                pairId: pairId,
                pairSecret: pairSecret,
                forwarderURL: forwarderURL,
                privateKeyB64: identity.rawPrivate.base64EncodedString(),
                publicKeyB64: identity.rawPublic.base64EncodedString(),
                peerPublicKeyB64: peerPublicKey?.base64EncodedString(),
                lastSyncUnixMs: lastSyncUnixMs,
                lastSyncOn: lastSyncOn,
                lastSyncSender: lastSyncSender,
                lastSyncViaLan: lastSyncViaLan,
                recentActivity: recentActivity.map {
                    PersistedSyncEvent(unixMs: $0.unixMs, on: $0.on, sender: $0.sender)
                }
            )
        )
    }

    private func autoUnpairIfExpired() {
        guard joined else {
            pairingExpired = true
            return
        }
        unpair(notifyPeer: false)
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

    private func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private static func makeQRImage(_ text: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = qrCorrection
        guard let output = filter.outputImage else {
            return nil
        }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: qrScale, y: qrScale))
        let color = CIFilter.falseColor()
        color.inputImage = scaled
        color.color0 = CIColor(red: 0, green: 0, blue: 0)
        color.color1 = CIColor(red: 1, green: 1, blue: 1)
        guard let colored = color.outputImage else {
            return nil
        }
        let extent = colored.extent.integral
        guard extent.width > 0, extent.height > 0 else {
            return nil
        }
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(colored, from: extent) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: extent.width, height: extent.height))
    }
}
