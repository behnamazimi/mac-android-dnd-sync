import Foundation
@testable import FocusSync

final class InMemorySyncLan: SyncLan {
    var onUiState: ((LanUiSnapshot) -> Void)?
    var onInbound: ((Dndsync_V1_DndState) -> Void)?
    var onInboundUnpair: ((Dndsync_V1_PairControl) -> Void)?
    var sent: [Dndsync_V1_DndState] = []
    var unpairs: [Dndsync_V1_PairControl] = []
    var started = false
    var pairId = ""

    func setPairId(_ pairId: String) {
        self.pairId = pairId
    }

    func start() {
        started = true
    }

    func stop() {
        started = false
    }

    func send(_ state: Dndsync_V1_DndState) {
        sent.append(state)
    }

    func sendUnpairNow(_ control: Dndsync_V1_PairControl) {
        unpairs.append(control)
    }
}

final class InMemorySyncCloud: SyncCloud {
    var posts: [Data] = []
    var deleted = false

    func postEnvelope(
        baseURL: String,
        pairId: String,
        secret: String,
        envelope: Data
    ) async throws {
        posts.append(envelope)
    }

    func deletePair(baseURL: String, pairId: String, secret: String) async throws {
        deleted = true
    }
}

final class FakeSyncPairing: SyncPairing {
    var joined = false
    var pairId = "dndsync-test"
    var pairSecret = "secret"
    var forwarderURL = "https://example.invalid"
    var lastSync: (unixMs: Int64, on: Bool, sender: String, viaLan: Bool)?
    var unpaired = false
    var cloudErrors: [String] = []
    var refreshCalls = 0

    func seal(_ plaintext: Data) throws -> Data { plaintext }
    func open(_ ciphertext: Data) -> Data? { ciphertext }

    func persistLastSync(unixMs: Int64, on: Bool, sender: String, viaLan: Bool) {
        lastSync = (unixMs, on, sender, viaLan)
    }

    func handleInboundUnpair(_ control: Dndsync_V1_PairControl) {
        unpaired = true
        joined = false
    }

    func noteCloudUnauthorized() {
        cloudErrors.append("unauthorized")
    }

    func noteCloudError(_ message: String) {
        cloudErrors.append(message)
    }

    func noteCloudSuccess() {}

    func refreshPairOrUnpair() async {
        refreshCalls += 1
    }
}
