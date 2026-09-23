import Foundation

struct PairPayload: Codable, Equatable {
    var forwarderURL: String
    var pairId: String
    var pairSecret: String
    var macE2ePublicKey: String
    var macApnsToken: String
    var macDeviceName: String? = nil

    enum CodingKeys: String, CodingKey {
        case forwarderURL = "forwarder_url"
        case pairId = "pair_id"
        case pairSecret = "pair_secret"
        case macE2ePublicKey = "mac_e2e_public_key"
        case macApnsToken = "mac_apns_token"
        case macDeviceName = "mac_device_name"
    }

    func jsonString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return text
    }

    static func parse(_ text: String) throws -> PairPayload {
        guard let data = text.data(using: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return try JSONDecoder().decode(PairPayload.self, from: data)
    }
}
