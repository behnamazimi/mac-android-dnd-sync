import Foundation
import os
import UserNotifications

final class ApnsPushReceiver {
    static let shared = ApnsPushReceiver()
    private static let log = Logger(subsystem: "com.dndsync.macos", category: "apns")

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
        debug("apns registered token=…\(deviceTokenHex.suffix(8))")
        onRegistrationChange?()
    }

    func didFail(error: Error) {
        registrationError = error.localizedDescription
        onRegistrationChange?()
    }

    func didReceive(userInfo: [String: Any]) {
        withdrawSyncNotification()
        onReceive?(userInfo)
        let hasEnvelope = userInfo["envelope_b64"] != nil
        let joined = isJoinedWake(userInfo["joined"])
        let command = userInfo["command"] as? String
        debug(
            "apns receive envelope=\(hasEnvelope) joined=\(joined) command=\(command ?? "—")"
        )
        if let encoded = userInfo["envelope_b64"] as? String {
            guard let envelope = CloudEnvelopeCodec.decodeBase64(encoded) else {
                debug("apns invalid envelope_b64")
                onEnvelopeError?("invalid envelope_b64")
                return
            }
            onEnvelope?(envelope)
            return
        }
        if joined {
            onJoinedWake?()
            return
        }
        guard let command else {
            debug("apns ignored keys=\(userInfo.keys.sorted())")
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

    private func withdrawSyncNotification() {
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { notifications in
            let ids = notifications.compactMap { note -> String? in
                let info = note.request.content.userInfo
                if info["envelope_b64"] != nil || info["joined"] != nil || info["command"] != nil {
                    return note.request.identifier
                }
                return nil
            }
            if !ids.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: ids)
            }
        }
    }

    static func debug(_ message: String) {
        #if DEBUG
        print("[DEBUG] \(message)")
        log.notice("[DEBUG] \(message, privacy: .public)")
        #endif
    }

    private func debug(_ message: String) {
        Self.debug(message)
    }
}
