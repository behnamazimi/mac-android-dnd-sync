package com.dndsync.android.ui.navigation

/** Whether a pairing screen was entered from first-run onboarding or from Settings' re-pair flow. */
enum class Origin { Onboarding, Repair }

/**
 * Route path constants for [DndSyncNavHost]. Kept as plain strings (rather than
 * kotlinx.serialization type-safe routes, not otherwise used in this project) so no
 * new Gradle plugin/dependency is needed for a single enum arg.
 */
object Routes {
    const val Welcome = "welcome"
    const val ConnectToMacPattern = "connect_to_mac/{origin}"
    const val ConnectingPattern = "connecting/{origin}"
    const val FocusAccess = "focus_access"
    const val NotificationsAccess = "notifications_access"
    const val AllSet = "all_set"
    const val Home = "home"
    const val Settings = "settings"
    const val RepairConfirm = "repair_confirm"
    const val UnpairConfirm = "unpair_confirm"
    const val About = "about"
    const val Licenses = "licenses"
    const val Diagnostics = "diagnostics"

    const val OriginArg = "origin"

    fun connectToMac(origin: Origin) = "connect_to_mac/${origin.name}"
    fun connecting(origin: Origin) = "connecting/${origin.name}"
}
