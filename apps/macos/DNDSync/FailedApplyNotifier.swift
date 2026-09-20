import Foundation
import UserNotifications

/// Posts a local notification when a remote on/off command from the phone
/// couldn't be applied (Shortcuts automation denied or a shortcut missing).
/// Mirrors the Android app's FailedOffNotifier. Callers are responsible for
/// only invoking `notifyFailedApply()` on the false→true edge of the
/// underlying dropped-apply condition, so this fires once per open incident
/// rather than once per dropped remote command.
@MainActor
enum FailedApplyNotifier {
    // Plain constants, not actor-isolated state — safe to read from any
    // context (e.g. AppDelegate's nonisolated UNUserNotificationCenterDelegate callbacks).
    nonisolated static let categoryIdentifier = "APPLY_DROPPED"
    private static let requestIdentifier = "apply-dropped"

    static func requestAuthorizationIfNeeded() {
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }
    }

    static func notifyFailedApply() {
        let category = categoryIdentifier
        let identifier = requestIdentifier
        let title = ProductCopy.applyDroppedNotificationTitle
        let body = ProductCopy.applyDropped
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.categoryIdentifier = category
            content.sound = .default
            try? await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            )
        }
    }
}
