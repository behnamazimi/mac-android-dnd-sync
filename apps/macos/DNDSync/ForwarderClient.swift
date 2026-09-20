import Foundation

enum ForwarderClientError: LocalizedError {
    case notConfigured
    case invalidURL
    case httpStatus(Int, String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "missing ForwarderSecrets.local.swift"
        case .invalidURL:
            return "invalid forwarder URL"
        case .httpStatus(let code, let body):
            return "HTTP \(code)\(body.isEmpty ? "" : ": \(body)")"
        case .transport(let message):
            return message
        }
    }
}

final class ForwarderClient {
    static let timeout: TimeInterval = 8

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = Self.timeout
        config.timeoutIntervalForResource = Self.timeout
        session = URLSession(configuration: config)
    }

    func registerDevice(
        baseURL: String,
        pairId: String,
        secret: String,
        sender: String,
        platform: String,
        token: String,
        e2ePublicKey: String?
    ) async throws {
        let url = try endpoint(baseURL, path: "/v1/pairs/\(pairId)/devices")
        var body: [String: String] = [
            "sender": sender,
            "platform": platform,
            "token": token,
        ]
        if let e2ePublicKey, !e2ePublicKey.isEmpty {
            body["e2e_public_key"] = e2ePublicKey
        }
        try await sendJSON(url: url, method: "PUT", secret: secret, body: body, expect: [204])
    }

    func createPair(
        baseURL: String,
        appKey: String,
        pairId: String,
        secretHash: String,
        sender: String,
        platform: String,
        token: String,
        e2ePublicKey: String?
    ) async throws {
        let url = try endpoint(baseURL, path: "/v1/pairs")
        var body: [String: String] = [
            "pair_id": pairId,
            "secret_hash": secretHash,
            "sender": sender,
            "platform": platform,
            "token": token,
        ]
        if let e2ePublicKey, !e2ePublicKey.isEmpty {
            body["e2e_public_key"] = e2ePublicKey
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appKey, forHTTPHeaderField: "X-App-Key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        try await send(request, expect: [201])
    }

    func joinPair(
        baseURL: String,
        pairId: String,
        secret: String,
        sender: String,
        platform: String,
        token: String,
        e2ePublicKey: String
    ) async throws {
        let url = try endpoint(baseURL, path: "/v1/pairs/\(pairId)/join")
        let body = [
            "sender": sender,
            "platform": platform,
            "token": token,
            "e2e_public_key": e2ePublicKey,
        ]
        try await sendJSON(url: url, method: "POST", secret: secret, body: body, expect: [204])
    }

    func listDevices(
        baseURL: String,
        pairId: String,
        secret: String
    ) async throws -> [ForwarderDevice] {
        let url = try endpoint(baseURL, path: "/v1/pairs/\(pairId)/devices")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        let data = try await send(request, expect: [200])
        let decoded = try JSONDecoder().decode(ForwarderDeviceList.self, from: data)
        return decoded.devices
    }

    func postEnvelope(
        baseURL: String,
        pairId: String,
        secret: String,
        envelope: Data
    ) async throws {
        let url = try endpoint(baseURL, path: "/v1/pairs/\(pairId)/envelopes")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/protobuf", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.httpBody = envelope
        try await send(request, expect: [204])
    }

    func deletePair(baseURL: String, pairId: String, secret: String) async throws {
        let url = try endpoint(baseURL, path: "/v1/pairs/\(pairId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        try await send(request, expect: [204])
    }

    private func endpoint(_ baseURL: String, path: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ForwarderClientError.notConfigured
        }
        let root = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        let suffix = path.hasPrefix("/") ? path : "/\(path)"
        guard let url = URL(string: root + suffix) else {
            throw ForwarderClientError.invalidURL
        }
        return url
    }

    private func sendJSON(
        url: URL,
        method: String,
        secret: String,
        body: [String: String],
        expect: Set<Int>
    ) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        try await send(request, expect: expect)
    }

    @discardableResult
    private func send(_ request: URLRequest, expect: Set<Int>) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ForwarderClientError.transport(error.localizedDescription)
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if !expect.contains(code) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ForwarderClientError.httpStatus(code, body)
        }
        return data
    }
}

struct ForwarderDeviceList: Codable {
    var devices: [ForwarderDevice]
}

struct ForwarderDevice: Codable {
    var sender: String
    var e2ePublicKey: String

    enum CodingKeys: String, CodingKey {
        case sender
        case e2ePublicKey = "e2e_public_key"
    }
}
