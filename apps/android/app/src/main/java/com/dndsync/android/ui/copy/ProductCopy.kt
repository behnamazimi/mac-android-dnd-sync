package com.dndsync.android.ui.copy

/**
 * Every user-facing string in the redesigned app, centralized. Same convention as
 * the app had before the redesign (kept deliberately: there's no i18n driver to
 * justify a move to `strings.xml`, and this keeps copy easy to review in one place).
 */
object ProductCopy {
    const val APP_NAME = "Do Not Disturb Sync"
    const val BACK = "Back"
    const val CLOSE = "Close"
    const val CANCEL = "Cancel"
    const val SETTINGS = "Settings"
    const val FLASHLIGHT_TURN_ON = "Turn flashlight on"
    const val FLASHLIGHT_TURN_OFF = "Turn flashlight off"
    const val PASTE_INSTEAD = "Paste the code instead"

    // Welcome
    const val WELCOME_TITLE = "One switch, two devices"
    const val WELCOME_BODY =
        "Turn Do Not Disturb on your phone or Mac, and the other follows. This app has no extra switch."
    const val WELCOME_PRIMARY = "Connect your Mac"

    // Connect to Mac
    const val CONNECT_TITLE = "Connect to Mac"
    const val CONNECT_REPAIR_TITLE = "Connect a different Mac"
    const val TAB_SCAN = "Scan QR"
    const val TAB_ENTER_CODE = "Enter code"
    const val SCAN_CAPTION = "Point at the QR code on your Mac"
    const val SCAN_TROUBLE = "Camera won't scan it?"
    const val CAMERA_DENIED =
        "Camera access is off. Allow it to scan, or paste the code instead."
    const val CAMERA_UNAVAILABLE = "This phone has no camera. Paste the code instead."
    const val ENTER_CODE_BODY = "Paste the code shown on your Mac"
    const val ENTER_CODE_PLACEHOLDER = "Code from your Mac"
    const val PASTE_FROM_CLIPBOARD = "Paste from clipboard"
    const val JOIN = "Connect"
    const val BAD_PAYLOAD = "That isn't a pairing code."
    const val JOIN_FAILED = "Couldn't connect. Check the internet and try again."
    const val PAIRING_CODE_REJECTED = "This code isn't valid anymore. Scan the QR on your Mac again."
    const val DOWNLOAD_MAC_APP = "Download the Mac app"

    // Connecting
    const val CONNECTING_TITLE = "Connecting…"
    const val CONNECTING_BODY = "Linking this phone to your Mac"
    const val CONNECTING_NETWORK_TITLE = "Needs the internet, even on Wi-Fi"
    const val CONNECTING_NETWORK_BODY = "Both devices confirm before they can sync."
    const val CONNECTING_WAITING_FCM = "Still waiting for Google to finish…"
    const val CONNECTING_RETRY = "Try again"

    // Do Not Disturb access (Android notification-policy permission, not Focus mode)
    const val FOCUS_ACCESS_HEADER = "Do Not Disturb access"
    const val FOCUS_ACCESS_TITLE = "Keep Do Not Disturb in sync"
    const val FOCUS_ACCESS_BODY =
        "$APP_NAME needs to see and change Do Not Disturb on this phone."
    const val FOCUS_ACCESS_PRIMARY = "Open access settings"
    const val FOCUS_ACCESS_STILL_DENIED =
        "Still off. Turn on $APP_NAME in the list, then come back."
    const val FOCUS_ACCESS_HINT = "The list opens on $APP_NAME"

    // Notifications
    const val NOTIFICATIONS_HEADER = "Notifications"
    const val NOTIFICATIONS_TITLE = "Get a ping if sync fails"
    const val NOTIFICATIONS_BODY =
        "That's the only time. Usually this phone or another mode kept Do Not Disturb on."
    const val NOTIFICATIONS_PRIMARY = "Allow notifications"
    const val SKIP = "Skip for now"

    // All set
    const val ALL_SET_TITLE = "You're connected"
    const val ALL_SET_CONTINUE = "Done"

    // Settings
    const val SETTINGS_TITLE = "Settings"
    const val PAIRED_DEVICE_SECTION = "Your Mac"
    const val CONNECTED = "Connected"
    const val NOT_CONNECTED = "Not connected"
    const val REPAIR = "Connect a different Mac"
    const val UNPAIR = "Unpair"
    const val SYNC_SECTION = "Sync"
    const val NEARBY_DEVICES = "Find your Mac on Wi-Fi"
    const val NOTIFY_ON_FAILURE = "Notify me if sync fails"
    const val PATH_NEARBY = "Nearby Wi-Fi"
    const val PATH_INTERNET = "Internet"
    const val DND_ON_SHORT = "On"
    const val DND_OFF_SHORT = "Off"
    const val BY_THIS_PHONE = "this phone"
    const val BY_THE_MAC = "the Mac"
    const val ABOUT_SECTION = "About"
    const val ABOUT_THE_APP = "About the app"

    // Re-pair confirm
    const val REPAIR_CONFIRM_TITLE = "Connect a different Mac"
    const val REPAIR_CONFIRM_HEADLINE = "This disconnects your current Mac"
    const val REPAIR_CONFIRM_BODY =
        "Sync stops until you scan a new QR code. Do Not Disturb still works on this phone."
    const val START_NEW_PAIRING = "Connect new Mac"

    // Unpair confirm
    const val UNPAIR_CONFIRM_TITLE = "Unpair"
    const val UNPAIR_CONFIRM_HEADLINE = "Stop syncing with this Mac?"
    const val UNPAIR_CONFIRM_BODY =
        "Your Mac gets the message too. Sync stops on both until you connect again."

    // About
    const val ABOUT_TITLE = "About"
    const val WHAT_WE_STORE_SECTION = "What we store"
    const val WHAT_WE_STORE_BODY =
        "We store a link between your devices and a way to reach this phone. We never store whether Do Not Disturb is on or off."
    const val SEE_SOURCE_ON_GITHUB = "See the source on GitHub"
    const val STAR_IF_IT_HELPS = "Star it if it helps."
    const val OPEN_SOURCE_LICENSES = "Open source licenses"
    const val LICENSE_INTER = "Inter"
    const val DIAGNOSTICS = "Diagnostics"

    // Diagnostics fallback
    const val EM_DASH = "—"
}

/**
 * Not on the Play Store yet. Both apps point at the same GitHub repo.
 * Releases (`/releases/latest`) is the download page (notarized `.dmg` +
 * signed `.apk`, both attached by `release.yml` on a version tag). The repo
 * root is About's source link. `/releases/latest` over a per-asset link since
 * asset URLs change every tag.
 */
object Distribution {
    const val GITHUB_REPO = "https://github.com/behnamazimi/mac-android-focus-sync"
    const val GITHUB_RELEASES = "https://github.com/behnamazimi/mac-android-focus-sync/releases/latest"
}
