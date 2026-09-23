import Foundation

enum ProductCopy {
    static let appName = "Focus Sync"
    static let androidAppName = "Do Not Disturb Sync"
    static let offlineTitle = "No network"
    static let offlineBody = "Connect to Wi-Fi or cellular to continue."
    static let diagnostics = "Diagnostics"

    static let welcomeTitle = "One switch, two devices"
    static let welcomeBody =
        "Turn Focus on your Mac or phone, and the other follows. This app has no extra switch."
    static let getStarted = "Get started"
    static let welcomeCaption = "About a minute. Keep your phone nearby."

    static let grantAccessTitle = "Allow notifications"
    static let grantAccessBody =
        "So this Mac can follow your phone when you're not on the same Wi-Fi. Shortcuts access comes after you add them."
    static let notificationsRowTitle = "Send Notifications"
    static let notificationsRowSubtitle =
        "Lets this Mac follow your phone when you're not on the same Wi-Fi."
    static let continueLabel = "Continue"
    static let automationDenied =
        "Shortcuts access is off. In System Settings → Privacy & Security → Automation, allow \(appName) to control Shortcuts."
    static let notificationsDenied =
        "Notifications are off. Allow them in System Settings so this Mac can follow your phone."
    static let openAutomation = "Open Automation settings"
    static let openNotifications = "Open Notifications settings"

    static let shortcutsTitle = "Add two shortcuts"
    static let shortcutsBody =
        "Add both shortcuts so this Mac can turn Focus on and off. Adding them won't change Focus."
    static let shortcutsProveBody =
        "Running both shortcuts. Allow \(appName) to control Shortcuts if macOS asks. Focus turns on, then off."
    static let addOn = "Add On shortcut"
    static let checkAgain = "Check again"
    static let onMissing = "\"\(ShortcutNames.on)\" isn't in Shortcuts yet. Click Add, then come back here."

    static let addOff = "Add Off shortcut"
    static let offMissing = "\"\(ShortcutNames.off)\" isn't in Shortcuts yet. Click Add, then come back here."

    static let shortcutRowOn = "On"
    static let shortcutRowOff = "Off"
    static let shortcutAdded = "Added"

    static let loginTitle = "Open at login"
    static let loginBody =
        "Keep \(appName) running so this Mac can follow your phone, even when you're not on the same Wi-Fi. If you quit the app, Focus won't update."
    static let openAtLogin = "Open at login"
    static let skipForNow = "Skip for now"

    static let qrBody =
        "Open \(androidAppName) on your phone and point the camera at this code. Keep this window open until you're connected."
    static let waitingApns = "Getting ready…"
    static let createPairFailed = "Couldn't start pairing. Check the internet and try again."
    static let tryAgain = "Try again"
    static let waitingPhone = "Waiting for your phone…"
    static let copyPairingCode = "Copy pairing code"
    static let downloadAndroidApp = "Download the Android app"
    static let seeSourceOnGitHub = "See the source on GitHub"
    static let starIfItHelps = "Star it if it helps."

    static let close = "Close"
    static let inSyncTitle = "In sync"
    static let howDoesThisWork = "How does this work?"
    static let howThisWorksBody =
        "Turn Focus on one device, and the other follows. Same Wi-Fi is fastest. If you're apart, we wake the other device over the internet. This app has no extra switch."
    static let granted = "Granted"
    static let notGranted = "Not granted"
    static let paired = "Paired"
    static let notPaired = "Not paired"
    static let dndOn = "Do Not Disturb On"
    static let dndOff = "Do Not Disturb Off"
    static let settings = "Settings"
    static let emDash = "—"

    static let rePair = "Pair again…"
    static let notifyIfSyncFails = "Notify me if sync fails"
    static let pairing = "Your phone"
    static let recentActivity = "Recent activity"
    static let general = "General"
    static let about = "About"
    static let advanced = "Advanced"
    static let openEllipsis = "Open…"
    static let unpair = "Unpair"
    static let unpairConfirmTitle = "Stop syncing with this phone?"
    static let unpairConfirmBody = "Your phone gets the message too. Sync stops on both until you connect again."
    static let cancel = "Cancel"

    static let dndOnWord = "on"
    static let dndOffWord = "off"
    static let dndOnShort = "On"
    static let dndOffShort = "Off"
    static let dndCaption = "Do Not Disturb"
    static let phoneFallback = "Phone"
    static let thisMac = "This Mac"
    static let byThisMac = "this Mac"
    static let byThePhone = "the phone"
    static let pathNearby = "Nearby Wi-Fi"
    static let pathInternet = "Internet"
    static let neverSynced = "No sync yet. Flip Focus on either device."

    static let pairingExpired = "Pairing expired. Connect again from Settings."
    static let shortcutsMissing = "Add the On and Off shortcuts so this Mac can follow your phone."
    static let applyDropped = "Couldn't update Focus. Finish setup, then try again."
    static let applyDroppedNotificationTitle = "\(appName) couldn't update Focus"
}

/// Not on the App Store yet — both apps point at the same GitHub repo.
/// Releases (`/releases/latest`) is the download page (notarized `.dmg` +
/// signed `.apk`, both attached by `release.yml` on a version tag). The repo
/// root is About's source link. `/releases/latest` over a per-asset link since
/// asset URLs change every tag.
enum Distribution {
    static let githubRepo = URL(string: "https://github.com/behnamazimi/mac-android-focus-sync")!
    static let githubReleases = URL(string: "https://github.com/behnamazimi/mac-android-focus-sync/releases/latest")!
}

enum MacDestination: Equatable, Hashable {
    case welcome
    case automation
    case shortcuts
    case loginItem
    case qr
    case status
}

struct OnboardingProgress: Equatable {
    var hasSeenWelcome: Bool
    var paired: Bool
    var notificationsGranted: Bool
    var automationDenied: Bool
    var probedAutomation: Bool
    var onExists: Bool
    var offExists: Bool
    /// True after setup has run both shortcuts, so the Automation prompt
    /// happens here instead of on the first real Focus change.
    var shortcutsProven: Bool
    var loginEnabled: Bool
    var loginSkipped: Bool
}

enum MacRouting {
    static func destination(_ progress: OnboardingProgress) -> MacDestination {
        if !progress.notificationsGranted {
            if !progress.hasSeenWelcome && !progress.paired { return .welcome }
            return .automation
        }
        if progress.paired {
            return .status
        }
        if !progress.hasSeenWelcome { return .welcome }
        if !Self.shortcutsAdded(progress)
            && (!progress.probedAutomation || progress.automationDenied) {
            return .automation
        }
        if !Self.shortcutsReady(progress) { return .shortcuts }
        if !progress.loginEnabled && !progress.loginSkipped { return .loginItem }
        return .qr
    }

    static func needsNetwork(_ progress: OnboardingProgress) -> Bool {
        if !progress.notificationsGranted {
            return false
        }
        if progress.paired {
            return true
        }
        if !progress.hasSeenWelcome {
            return false
        }
        if !Self.shortcutsAdded(progress)
            && (!progress.probedAutomation || progress.automationDenied) {
            return false
        }
        if !Self.shortcutsReady(progress) {
            return false
        }
        if !progress.loginEnabled && !progress.loginSkipped {
            return false
        }
        return true
    }

    private static func shortcutsAdded(_ progress: OnboardingProgress) -> Bool {
        progress.onExists && progress.offExists
    }

    /// Added, and both have been run so the Automation prompt already happened.
    private static func shortcutsReady(_ progress: OnboardingProgress) -> Bool {
        shortcutsAdded(progress) && progress.shortcutsProven
    }

    static func lastError(
        paired: Bool,
        pairingExpired: Bool,
        automationDenied: Bool,
        onExists: Bool,
        offExists: Bool,
        applyDropped: Bool,
        lastCloudError: String?,
        lastLanError: String?,
        lanBlocking: Bool
    ) -> String {
        if pairingExpired { return ProductCopy.pairingExpired }
        if paired && (automationDenied || !onExists || !offExists) {
            if automationDenied { return ProductCopy.automationDenied }
            return ProductCopy.shortcutsMissing
        }
        if applyDropped { return ProductCopy.applyDropped }
        if let cloud = lastCloudError, cloud != ProductCopy.emDash, !cloud.isEmpty {
            return cloud
        }
        if lanBlocking, let lan = lastLanError, lan != ProductCopy.emDash, !lan.isEmpty {
            return lan
        }
        return ProductCopy.emDash
    }
}

enum LastSyncPresentation {
    static func hasSync(_ unixMs: Int64) -> Bool { unixMs > 0 }

    static func eventLine(sender: String, on: Bool, peerName: String) -> String {
        let who: String
        switch sender {
        case LanConstants.senderAndroid:
            who = peerName.isEmpty ? ProductCopy.phoneFallback : peerName
        case LanConstants.senderMac:
            who = ProductCopy.thisMac
        default:
            who = peerName.isEmpty ? ProductCopy.phoneFallback : peerName
        }
        let state = on ? ProductCopy.dndOnWord : ProductCopy.dndOffWord
        return "\(who) turned Focus \(state)"
    }

    static func pathLabel(viaLan: Bool) -> String {
        viaLan ? ProductCopy.pathNearby : ProductCopy.pathInternet
    }

    static func truncatedPairId(_ pairId: String) -> String {
        if pairId.isEmpty {
            return ProductCopy.emDash
        }
        return pairId.count <= 8 ? pairId : "…\(pairId.suffix(8))"
    }

    static func peerLabel(_ name: String) -> String {
        name.isEmpty ? ProductCopy.phoneFallback : name
    }
}

/// One row of Home's "Recent activity" list — the same trail Android keeps
/// (max 5, seeded from and updated alongside the single persisted last-sync;
/// see `PairSession.persistLastSync`). Tracks `sender` (not `viaLan`): rows
/// say who flipped Focus, not which path carried it — end users don't care
/// whether a sync used the LAN or the cloud forwarder.
struct SyncEvent: Equatable, Identifiable {
    var unixMs: Int64
    var on: Bool
    var sender: String
    var id: Int64 { unixMs }
}

enum RecentActivity {
    static let maxEvents = 5

    static func stateLabel(on: Bool) -> String {
        on ? ProductCopy.dndOnShort : ProductCopy.dndOffShort
    }

    static func actorLabel(sender: String) -> String {
        sender == LanConstants.senderMac ? ProductCopy.byThisMac : ProductCopy.byThePhone
    }

    static func line(on: Bool, sender: String) -> String {
        "\(stateLabel(on: on)) by \(actorLabel(sender: sender))"
    }

    /// Prepends `event` to `current`, dropping any existing row with the same
    /// `unixMs` and capping at `maxEvents`. `unixMs == 0` means "no sync yet"
    /// (an unpair, or a restore before any sync) and clears the trail.
    static func appending(_ event: SyncEvent, to current: [SyncEvent]) -> [SyncEvent] {
        guard LastSyncPresentation.hasSync(event.unixMs) else { return [] }
        return ([event] + current.filter { $0.unixMs != event.unixMs }).prefix(maxEvents).map { $0 }
    }
}
