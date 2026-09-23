import Foundation
import Network

final class LocalCommandServer {
    static let host = "127.0.0.1"
    static let port: NWEndpoint.Port = 8787

    static var portNumber: UInt16 { port.rawValue }

    static var diagnosticsCurlHint: String {
        "From a local terminal: curl -X POST http://\(host):\(portNumber)/on or /off"
    }

    var onCommand: ((String) -> Void)?

    private let queue = DispatchQueue(label: "com.dndsync.macos.local-command")
    private var listener: NWListener?

    @discardableResult
    func start() -> Bool {
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        parameters.allowLocalEndpointReuse = true

        do {
            let listener = try NWListener(using: parameters, on: Self.port)
            self.listener = listener
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.start(queue: queue)
            return true
        } catch {
            return false
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    deinit {
        stop()
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, buffer: Data())
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }
            if error != nil {
                connection.cancel()
                return
            }
            var next = buffer
            if let data {
                next.append(data)
            }
            if let headerEnd = next.range(of: Data("\r\n\r\n".utf8))
                ?? next.range(of: Data("\n\n".utf8)) {
                self.respond(to: connection, request: Data(next[..<headerEnd.lowerBound]))
                return
            }
            if isComplete {
                self.respond(to: connection, request: next)
                return
            }
            if next.count > 8192 {
                self.send(status: 400, to: connection)
                return
            }
            self.receive(connection, buffer: next)
        }
    }

    private func respond(to connection: NWConnection, request: Data) {
        guard let text = String(data: request, encoding: .utf8) else {
            send(status: 400, to: connection)
            return
        }
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else {
            send(status: 400, to: connection)
            return
        }
        let method = String(parts[0])
        let path = String(parts[1])
        guard method == "POST" else {
            send(status: 405, to: connection)
            return
        }
        let command: String
        switch path {
        case "/on":
            command = "on"
        case "/off":
            command = "off"
        default:
            send(status: 404, to: connection)
            return
        }
        onCommand?(command)
        send(status: 200, to: connection)
    }

    private func send(status: Int, to connection: NWConnection) {
        let reason: String
        switch status {
        case 200:
            reason = "OK"
        case 400:
            reason = "Bad Request"
        case 404:
            reason = "Not Found"
        case 405:
            reason = "Method Not Allowed"
        default:
            reason = "Error"
        }
        let header = "HTTP/1.1 \(status) \(reason)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(
            content: Data(header.utf8),
            isComplete: true,
            completion: .contentProcessed { _ in
                connection.cancel()
            },
        )
    }
}
