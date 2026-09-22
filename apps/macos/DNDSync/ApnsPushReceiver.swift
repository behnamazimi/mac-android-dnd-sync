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
    /// Silent join poke. No Focus bit. The Mac asks for the phone's key once.
    var onJoinedWake: (() -> Void)?

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
        if isJoinedWake(userInfo["joined"]) {
            onJoinedWake?()
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

    private func isJoinedWake(_ value: Any?) -> Bool {
        if let flag = value as? Bool {
            return flag
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return false
    }
}
