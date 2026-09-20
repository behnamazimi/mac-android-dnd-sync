package com.dndsync.android.ui.copy

/** Copy for Home's one status card across its four states. See `ui/home/HomeStatus.kt`. */
object HomeCopy {
    const val DND_ON_HEADLINE = "Do Not Disturb is on"
    const val DND_OFF_HEADLINE = "Do Not Disturb is off"

    fun syncedWith(peer: String): String = "Synced with $peer"

    const val SYNCING_HEADLINE = "Syncing…"
    const val SYNCING_SUBLINE = "Catching up your other device"

    const val NEEDS_ATTENTION_HEADLINE = "Needs a quick fix"
    const val FOCUS_ACCESS_REVOKED_SUBLINE = "Do Not Disturb access was turned off in Settings"

    const val NO_NETWORK_HEADLINE = "No network"
    const val NO_NETWORK_SUBLINE = "Waiting for Wi-Fi or cellular"

    const val PAIRING_EXPIRED_HEADLINE = "Pairing expired"
    const val PAIRING_EXPIRED_SUBLINE = "Connect again from Settings"
    const val OPEN_SETTINGS = "Open Settings"

    const val APPLY_DROPPED_HEADLINE = "Couldn't update Do Not Disturb"
    const val APPLY_DROPPED_SUBLINE = "Finish setup, then try again"

    const val OFF_DIDNT_APPLY_HEADLINE = "Couldn't turn Do Not Disturb off"
    const val OFF_DIDNT_APPLY_SUBLINE = "This phone kept it on"
    const val OPEN_FOCUS_SETTINGS = "Open Modes settings"

    const val RECENT_ACTIVITY = "Recent activity"
    const val RECENT_ACTIVITY_EMPTY = "No syncs yet. Flip Do Not Disturb on either device."
}
