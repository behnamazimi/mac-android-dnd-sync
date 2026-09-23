import Foundation
import Intents

/// Reads whether a Focus is currently on for this Mac, and watches for flips.
/// The live source is `INFocusStatusCenter`, which needs the Communication
/// Notifications entitlement plus the user's Focus Status permission (see
/// `FocusStatusAccess`). The private `DNDStateService` rejects every
/// third-party client, so it is not used. Control Center rarely posts
/// `_NSDoNotDisturb*` any more; those names stay as a fallback.
final class FocusStatusObserver: NSObject {
    static let enabledName = Notification.Name("_NSDoNotDisturbEnabledNotification")
    static let disabledName = Notification.Name("_NSDoNotDisturbDisabledNotification")

    /// `originates` is false for the first snapshot so launching the app
    /// (or granting access) does not push the current Focus to the phone.
    var onChange: ((Bool, String, Bool) -> Void)?

    private var lastOn: Bool?
    private var pollTimer: DispatchSourceTimer?

    override init() {
        super.init()
        let center = DistributedNotificationCenter.default()
        center.suspended = false
        for name in [Self.enabledName, Self.disabledName] {
            center.addObserver(
                self,
                selector: #selector(handleLegacyNotification(_:)),
                name: name,
                object: nil,
                suspensionBehavior: .deliverImmediately
            )
        }
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            startPolling()
        }
    }

    deinit {
        pollTimer?.cancel()
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func refresh() {
        poll()
    }

    @objc private func handleLegacyNotification(_ notification: Notification) {
        publish(Self.resolveEnabled(notification), originates: true)
    }

    /// Control Center posts *Enabled* / *Disabled* as separate names and often
    /// leaves `object` / `userInfo` empty. Older macOS stuffed a bool into the
    /// Enabled notification instead. Prefer an explicit payload, then the name.
    static func resolveEnabled(_ notification: Notification) -> Bool {
        if let enabled = parseEnabled(notification) {
            return enabled
        }
        return notification.name == enabledName
    }

    /// `INFocusStatusCenter` has no change callback on macOS, so poll. The
    /// status is a cheap local read. Until access is granted `isFocused`
    /// stays nil and nothing is published.
    private func startPolling() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 1)
        timer.setEventHandler { [weak self] in
            self?.poll()
        }
        timer.resume()
        pollTimer = timer
    }

    private func poll() {
        guard FocusStatusAccess.current == .granted,
              let enabled = INFocusStatusCenter.default.focusStatus.isFocused
        else {
            return
        }
        publish(enabled, originates: lastOn != nil)
    }

    private func publish(_ enabled: Bool, originates: Bool) {
        if lastOn == enabled {
            return
        }
        lastOn = enabled
        let text = enabled ? "Focus: on" : "Focus: off"
        if Thread.isMainThread {
            onChange?(enabled, text, originates)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onChange?(enabled, text, originates)
            }
        }
    }

    private static func parseEnabled(_ notification: Notification) -> Bool? {
        if let enabled = bool(from: notification.object) {
            return enabled
        }
        guard let userInfo = notification.userInfo else {
            return nil
        }
        let keys = ["enabled", "state", "kEnabled", "DNDEnabled", "interruptionState"]
        for key in keys {
            if let enabled = bool(from: userInfo[key]) {
                return enabled
            }
        }
        for value in userInfo.values {
            if let enabled = bool(from: value) {
                return enabled
            }
        }
        return nil
    }

    private static func bool(from value: Any?) -> Bool? {
        switch value {
        case let number as NSNumber:
            return number.boolValue
        case let number as Int:
            return number != 0
        case let flag as Bool:
            return flag
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["1", "true", "yes", "on", "enabled"].contains(trimmed) {
                return true
            }
            if ["0", "false", "no", "off", "disabled"].contains(trimmed) {
                return false
            }
            return nil
        default:
            return nil
        }
    }
}

/// The user's Focus Status permission (System Settings → Privacy &
/// Security → Focus). Without it `INFocusStatusCenter` reports nothing.
enum FocusStatusAccess: Equatable {
    case notDetermined
    case granted
    case denied

    static var current: FocusStatusAccess {
        map(INFocusStatusCenter.default.authorizationStatus)
    }

    static func request() async -> FocusStatusAccess {
        await withCheckedContinuation { continuation in
            INFocusStatusCenter.default.requestAuthorization { status in
                continuation.resume(returning: map(status))
            }
        }
    }

    private static func map(_ status: INFocusStatusAuthorizationStatus) -> FocusStatusAccess {
        switch status {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        default:
            return .notDetermined
        }
    }
}
