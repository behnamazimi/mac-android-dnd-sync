import Foundation

final class ApnsPushReceiver {
    static let shared = ApnsPushReceiver()

    private(set) var deviceTokenHex = ""
    private(set) var registrationError: String?

    var onCommand: ((String) -> Void)?
    var onRegistrationChange: (() -> Void)?
    var onReceive: (([String: Any]) -> Void)?
    var onEnvelope: ((Dndsync_V1_CloudEnvelope) -> Void)?
    var onEnvelopeError: ((String) -> Void)?

    private init() {}

    func didRegister(deviceToken: Data) {
        deviceTokenHex = deviceToken.map { String(format: "%02x", $0) }.joined()
        registrationError = nil
        onRegistrationChange?()
    }

    func didFail(error: Error) {
        registrationError = error.localizedDescription
        onRegistrationChange?()
    }

    func didReceive(userInfo: [String: Any]) {
        onReceive?(userInfo)
        if let encoded = userInfo["envelope_b64"] as? String {
            guard let envelope = CloudEnvelopeCodec.decodeBase64(encoded) else {
                onEnvelopeError?("invalid envelope_b64")
                return
            }
            onEnvelope?(envelope)
            return
        }
        guard let command = userInfo["command"] as? String else {
            return
        }
        switch command {
        case "on", "off":
            onCommand?(command)
        default:
            break
        }
    }
}
