import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var chrome: ProductChrome?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start hidden from the Dock/Cmd+Tab — ProductChrome flips this to
        // `.regular` as soon as it shows the main window (and back to
        // `.accessory` once every window is closed). The status item it
        // installs is the one thing that's always present.
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self
        // Remote registration waits until notification permission is granted.
        // Registering first files the topic as non-waking, and later pushes
        // are dropped.
        ApnsPushReceiver.debug("apns listener ready")
        ApnsPushReceiver.reregisterIfAuthorized()
        chrome = ProductChrome()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Syncing (LAN listener, APNs handling, command server) must keep
        // running even with every window closed — closing a window hides it
        // (see ProductChrome.windowShouldClose), it doesn't quit the app.
        false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        chrome?.becomeActive()
        ApnsPushReceiver.reregisterIfAuthorized()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        chrome?.showMainWindow()
        return true
    }

    @MainActor
    func openSettingsFromMenuCommand() {
        NSApp.activate()
        chrome?.showSettings()
    }

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        ApnsPushReceiver.shared.didRegister(deviceToken: deviceToken)
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        ApnsPushReceiver.shared.didFail(error: error)
    }

    func application(
        _ application: NSApplication,
        didReceiveRemoteNotification userInfo: [String: Any]
    ) {
        ApnsPushReceiver.debug("apns system callback")
        ApnsPushReceiver.shared.didReceive(userInfo: userInfo)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        ApnsPushReceiver.shared.didReceive(userInfo: dictionary(from: notification.request.content.userInfo))
        completionHandler([])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.content.categoryIdentifier == FailedApplyNotifier.categoryIdentifier {
            Task { @MainActor in
                NSApp.activate()
                chrome?.showMainWindow()
            }
        }
        ApnsPushReceiver.shared.didReceive(userInfo: dictionary(from: response.notification.request.content.userInfo))
        completionHandler()
    }

    private func dictionary(from userInfo: [AnyHashable: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in userInfo {
            if let key = key as? String {
                result[key] = value
            }
        }
        return result
    }
}
