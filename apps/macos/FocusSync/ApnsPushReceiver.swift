import AppKit
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
    var onReceive: ((String, [String: Any]) -> Void)?
    var onEnvelope: ((Dndsync_V1_CloudEnvelope) -> Void)?
    var onEnvelopeError: ((String) -> Void)?
    /// Silent join poke. No Focus bit. The Mac asks for the phone's key once.
    var onJoinedWake: (() -> Void)?

    private init() {}

    /// Same order as the APNs probe: a regular app, permission, then register.
    /// The probe never sets an accessory policy. Registering this process
    /// while it is an accessory agent files the topic as non-waking.
    static func requestPermissionAndRegister() async {
        guard NSApp.activationPolicy() == .regular else {
            debug("apns skip register while accessory")
            return
        }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        debug("apns notification auth=\(settings.authorizationStatus.rawValue)")
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { return }
            registerIfRegular()
        case .authorized, .provisional:
            registerIfRegular()
        case .denied:
            break
        @unknown default:
            break
        }
    }

    static func reregisterIfAuthorized() {
        Task { @MainActor in
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
            else { return }
            registerIfRegular()
        }
    }

    private static func registerIfRegular() {
        guard NSApp.activationPolicy() == .regular else {
            debug("apns skip register while accessory")
            return
        }
        NSApplication.shared.registerForRemoteNotifications()
        debug("apns register")
    }

    func didRegister(deviceToken: Data) {
        deviceTokenHex = deviceToken.map { String(format: "%02x", $0) }.joined()
        registrationError = nil
        debug("apns registered token=\(deviceTokenHex)")
        onRegistrationChange?()
    }

    func didFail(error: Error) {
        registrationError = error.localizedDescription
        onRegistrationChange?()
    }

    func didReceive(userInfo: [String: Any], source: String) {
        onReceive?(source, userInfo)
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
