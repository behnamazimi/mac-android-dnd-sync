import Darwin
import Foundation

/// Reads whether a Focus is currently silencing this Mac, and watches for
/// flips. Control Center no longer posts `_NSDoNotDisturb*` on current
/// macOS — those names stay as a fallback. The live source is
/// `DNDStateService` in the private DoNotDisturb framework, loaded at
/// runtime so a missing framework cannot crash launch.
final class FocusStatusObserver: NSObject {
    static let enabledName = Notification.Name("_NSDoNotDisturbEnabledNotification")
    static let disabledName = Notification.Name("_NSDoNotDisturbDisabledNotification")

    /// `originates` is false for the first snapshot so launching the app
    /// does not push the current Focus to the phone.
    var onChange: ((Bool, String, Bool) -> Void)?

    private var dndService: AnyObject?
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
            startDNDStateService()
        }
    }

    deinit {
        pollTimer?.cancel()
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func refresh() {
        guard let service = dndService else { return }
        DNDFocusBridge.query(service) { [weak self] state in
            self?.apply(state: state, originates: true)
        }
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

    static func isOn(willSuppressInterruptions: Bool?, isActive: Bool?) -> Bool? {
        if let suppress = willSuppressInterruptions {
            return suppress
        }
        return isActive
    }

    @objc(stateService:didReceiveDoNotDisturbStateUpdate:)
    func stateService(_ service: Any, didReceiveDoNotDisturbStateUpdate update: Any) {
        apply(state: DNDFocusBridge.state(fromUpdate: update), originates: true)
    }

    private func startDNDStateService() {
        guard let service = DNDFocusBridge.makeService() else { return }
        dndService = service
        DNDFocusBridge.query(service) { [weak self] state in
            self?.apply(state: state, originates: false)
        }
        startPolling(service)
    }

    private func startPolling(_ service: AnyObject) {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            DNDFocusBridge.query(service) { state in
                self?.apply(state: state, originates: true)
            }
        }
        timer.resume()
        pollTimer = timer
    }

    private func apply(state: AnyObject?, originates: Bool) {
        guard let state, let enabled = DNDFocusBridge.isOn(fromState: state) else {
            return
        }
        publish(enabled, originates: originates)
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

/// Soft-links DoNotDisturb.framework. Selectors are strings on purpose —
/// a hard link would crash on an OS that renamed the class.
private enum DNDFocusBridge {
    private static let frameworkPaths = [
        "/System/Library/PrivateFrameworks/DoNotDisturb.framework/DoNotDisturb",
        "/System/Library/PrivateFrameworks/DoNotDisturb.framework/Versions/A/DoNotDisturb",
    ]

    static func makeService() -> AnyObject? {
        for path in frameworkPaths {
            _ = dlopen(path, RTLD_LAZY)
        }
        guard let cls: AnyClass = NSClassFromString("DNDStateService") else {
            return nil
        }
        let sel = NSSelectorFromString("serviceForClientIdentifier:")
        let object = cls as AnyObject
        guard object.responds(to: sel) else { return nil }
        let identifier = Bundle.main.bundleIdentifier ?? "com.dndsyncapp.macos"
        return object.perform(sel, with: identifier)?.takeUnretainedValue()
    }

    static func query(_ service: AnyObject, completion: @escaping (AnyObject?) -> Void) {
        let sel = NSSelectorFromString("queryCurrentStateWithCompletionHandler:")
        guard service.responds(to: sel) else {
            completion(nil)
            return
        }
        let block: @convention(block) (AnyObject?, NSError?) -> Void = { state, _ in
            DispatchQueue.main.async { completion(state) }
        }
        _ = service.perform(sel, with: unsafeBitCast(block, to: AnyObject.self))
    }

    static func state(fromUpdate update: Any) -> AnyObject? {
        let object = update as AnyObject
        if object.responds(to: NSSelectorFromString("state")) {
            return object.value(forKey: "state") as AnyObject?
        }
        return object
    }

    static func isOn(fromState state: AnyObject) -> Bool? {
        FocusStatusObserver.isOn(
            willSuppressInterruptions: bool(from: state.value(forKey: "willSuppressInterruptions")),
            isActive: bool(from: state.value(forKey: "active"))
        )
    }

    private static func bool(from value: Any?) -> Bool? {
        switch value {
        case let number as NSNumber:
            return number.boolValue
        case let flag as Bool:
            return flag
        default:
            return nil
        }
    }
}
