import Foundation
import Network

struct LanUiSnapshot {
    var advertising = false
    var browsing = false
    var connected = false
    var lastError: String?
}

final class LanSyncService {
    var onUiState: ((LanUiSnapshot) -> Void)?
    var onInbound: ((Dndsync_V1_DndState) -> Void)?
    var onInboundUnpair: ((Dndsync_V1_PairControl) -> Void)?

    private let queue = DispatchQueue(label: "com.dndsync.macos.lan")
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var accumulator = LengthPrefixedFramer.Accumulator()
    private var ui = LanUiSnapshot()
    private var pairId = LanConstants.pairId
    private var running = false

    func setPairId(_ pairId: String) {
        queue.async { [weak self] in
            guard let self else { return }
            if self.pairId == pairId {
                return
            }
            self.pairId = pairId
            if self.running {
                self.stopLocked()
                self.startLocked()
            }
        }
    }

    func start() {
        queue.async { [weak self] in
            self?.startLocked()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.stopLocked()
        }
    }

    deinit {
        queue.sync { stopLocked() }
    }

    func send(_ state: Dndsync_V1_DndState) {
        queue.async { [weak self] in
            self?.sendLocked(state)
        }
    }

    func sendUnpairNow(_ control: Dndsync_V1_PairControl) {
        // Wait off the LAN queue: `contentProcessed` also lands there, so a
        // `queue.sync` wait would deadlock. Unpair then immediately `stop()`s,
        // and `cancel()` drops anything still sitting in Network.framework.
        let done = DispatchSemaphore(value: 0)
        queue.async { [weak self] in
            guard let self else {
                done.signal()
                return
            }
            self.sendControlLocked(control, completion: { done.signal() })
        }
        _ = done.wait(timeout: .now() + 1)
    }

    private func startLocked() {
        running = true
        startListener()
        startBrowser()
    }

    private func stopLocked() {
        running = false
        browser?.cancel()
        browser = nil
        listener?.cancel()
        listener = nil
        dropConnection(reason: nil)
        ui = LanUiSnapshot()
        publishUi()
    }

    private func startListener() {
        let parameters = NWParameters.tcp
        do {
            let listener = try NWListener(using: parameters)
            var txt = NWTXTRecord()
            txt[LanConstants.pairTxtKey] = pairId
            listener.service = NWListener.Service(
                name: LanConstants.macInstanceName,
                type: LanConstants.serviceType,
                txtRecord: txt
            )
            listener.stateUpdateHandler = { [weak self] state in
                self?.queue.async {
                    self?.handleListenerState(state)
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.queue.async {
                    self?.accept(connection)
                }
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            fail("listener failed: \(error.localizedDescription)")
        }
    }

    private func startBrowser() {
        let browser = NWBrowser(
            for: .bonjourWithTXTRecord(type: LanConstants.serviceType, domain: nil),
            using: .tcp
        )
        browser.stateUpdateHandler = { [weak self] state in
            self?.queue.async {
                self?.handleBrowserState(state)
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.queue.async {
                self?.handleBrowseResults(results)
            }
        }
        self.browser = browser
        browser.start(queue: queue)
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            ui.advertising = true
            publishUi()
        case .failed(let error):
            ui.advertising = false
            fail("listener: \(error.localizedDescription)")
        case .cancelled:
            ui.advertising = false
            publishUi()
        default:
            break
        }
    }

    private func handleBrowserState(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            ui.browsing = true
            publishUi()
        case .failed(let error):
            ui.browsing = false
            fail("browser: \(error.localizedDescription)")
        case .cancelled:
            ui.browsing = false
            publishUi()
        default:
            break
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        // Mac never dials. Prefer IPv4 when both families appear so the
        // debug UI reflects the address Android is likely to use.
        var ipv4Peer = false
        var anyPeer = false
        for result in results {
            guard isMatchingPeer(result) else { continue }
            anyPeer = true
            if endpointIsIPv4(result.endpoint) {
                ipv4Peer = true
            }
        }
        _ = ipv4Peer || anyPeer
    }

    private func isMatchingPeer(_ result: NWBrowser.Result) -> Bool {
        guard case .service(let name, _, _, _) = result.endpoint else {
            return false
        }
        if name == LanConstants.macInstanceName {
            return false
        }
        if case .bonjour(let txt) = result.metadata {
            return txt[LanConstants.pairTxtKey] == pairId
        }
        return false
    }

    private func endpointIsIPv4(_ endpoint: NWEndpoint) -> Bool {
        if case .hostPort(let host, _) = endpoint {
            if case .ipv4 = host {
                return true
            }
        }
        return false
    }

    private func accept(_ incoming: NWConnection) {
        if let existing = connection {
            switch existing.state {
            case .ready:
                incoming.cancel()
                return
            default:
                existing.cancel()
            }
        }
        accumulator = LengthPrefixedFramer.Accumulator()
        connection = incoming
        incoming.stateUpdateHandler = { [weak self] state in
            self?.queue.async {
                self?.handleConnectionState(state)
            }
        }
        incoming.start(queue: queue)
        receive(on: incoming)
    }

    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            ui.connected = true
            ui.lastError = nil
            publishUi()
        case .failed(let error):
            dropConnection(reason: error.localizedDescription)
        case .cancelled:
            dropConnection(reason: "disconnected")
        default:
            break
        }
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: LanConstants.maxFrameBytes) { [weak self] data, _, isComplete, error in
            self?.queue.async {
                guard let self else { return }
                if let data, !data.isEmpty {
                    do {
                        let payloads = try self.accumulator.append(data)
                        for payload in payloads {
                            if let control = PairControlFrames.decode(payload) {
                                self.onInboundUnpair?(control)
                            } else if let state = DndStateFrames.decode(payload) {
                                self.onInbound?(state)
                            }
                        }
                    } catch {
                        self.dropConnection(reason: error.localizedDescription)
                        return
                    }
                }
                if let error {
                    self.dropConnection(reason: error.localizedDescription)
                    return
                }
                if isComplete {
                    self.dropConnection(reason: "disconnected")
                    return
                }
                if self.connection === connection {
                    self.receive(on: connection)
                }
            }
        }
    }

    private func sendLocked(_ state: Dndsync_V1_DndState) {
        guard let connection, connection.state == .ready else {
            return
        }
        do {
            let data = try DndStateFrames.encode(state)
            connection.send(content: data, completion: .contentProcessed { _ in })
        } catch {
            fail("send failed: \(error.localizedDescription)")
        }
    }

    private func sendControlLocked(
        _ control: Dndsync_V1_PairControl,
        completion: @escaping () -> Void
    ) {
        guard let connection, connection.state == .ready else {
            completion()
            return
        }
        do {
            let data = try LengthPrefixedFramer.frame(control.serializedData())
            // `isComplete: true` half-closes after this frame so `stop()`'s
            // `cancel()` cannot drop it.
            connection.send(
                content: data,
                isComplete: true,
                completion: .contentProcessed { _ in completion() }
            )
        } catch {
            fail("send failed: \(error.localizedDescription)")
            completion()
        }
    }

    private func dropConnection(reason: String?) {
        if connection != nil {
            connection?.cancel()
            connection = nil
            accumulator = LengthPrefixedFramer.Accumulator()
            ui.connected = false
            if let reason {
                ui.lastError = reason
            }
            publishUi()
        } else if let reason {
            fail(reason)
        }
    }

    private func fail(_ message: String) {
        ui.lastError = message
        publishUi()
    }

    private func publishUi() {
        let snapshot = ui
        onUiState?(snapshot)
    }
}
