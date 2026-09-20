import Foundation

protocol SyncLan: AnyObject {
    var onUiState: ((LanUiSnapshot) -> Void)? { get set }
    var onInbound: ((Dndsync_V1_DndState) -> Void)? { get set }
    var onInboundUnpair: ((Dndsync_V1_PairControl) -> Void)? { get set }
    func setPairId(_ pairId: String)
    func start()
    func stop()
    func send(_ state: Dndsync_V1_DndState)
    func sendUnpairNow(_ control: Dndsync_V1_PairControl)
}

extension LanSyncService: SyncLan {}

protocol SyncCloud: AnyObject {
    func postEnvelope(
        baseURL: String,
        pairId: String,
        secret: String,
        envelope: Data
    ) async throws

    func deletePair(baseURL: String, pairId: String, secret: String) async throws
}

extension ForwarderClient: SyncCloud {}

protocol SyncPairing: AnyObject {
    var joined: Bool { get }
    var pairId: String { get }
    var pairSecret: String { get }
    var forwarderURL: String { get }
    func seal(_ plaintext: Data) throws -> Data
    func open(_ ciphertext: Data) -> Data?
    func persistLastSync(unixMs: Int64, on: Bool, sender: String, viaLan: Bool)
    func handleInboundUnpair(_ control: Dndsync_V1_PairControl)
    func noteCloudUnauthorized()
    func noteCloudError(_ message: String)
    func noteCloudSuccess()
}

extension PairSession: SyncPairing {}
