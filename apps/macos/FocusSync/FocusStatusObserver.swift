import Foundation

final class FocusStatusObserver: NSObject {
    static let enabledName = Notification.Name("_NSDoNotDisturbEnabledNotification")
    static let disabledName = Notification.Name("_NSDoNotDisturbDisabledNotification")

    var onChange: ((Bool, String) -> Void)?

    override init() {
        super.init()
        let center = DistributedNotificationCenter.default()
        center.suspended = false
        for name in [Self.enabledName, Self.disabledName] {
            center.addObserver(
                self,
                selector: #selector(handleNotification(_:)),
                name: name,
                object: nil,
                suspensionBehavior: .deliverImmediately
            )
        }
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func handleNotification(_ notification: Notification) {
        let enabled = Self.resolveEnabled(notification)
        onChange?(enabled, enabled ? "Focus: on" : "Focus: off")
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
