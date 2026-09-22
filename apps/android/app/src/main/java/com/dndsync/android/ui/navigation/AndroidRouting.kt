package com.dndsync.android.ui.navigation

data class OnboardingProgress(
    val hasStoredPair: Boolean,
    val joined: Boolean,
    val policyAccessGranted: Boolean,
    val notificationsGranted: Boolean,
    val onboardingComplete: Boolean,
)

enum class AndroidDestination {
    Welcome,
    Connecting,
    FocusAccess,
    NotificationsAccess,
    Home,
}

object AndroidRouting {
    fun destination(progress: OnboardingProgress): AndroidDestination {
        if (!progress.hasStoredPair) {
            return AndroidDestination.Welcome
        }
        if (progress.onboardingComplete) {
            return AndroidDestination.Home
        }
        if (progress.joined) {
            if (!progress.policyAccessGranted) {
                return AndroidDestination.FocusAccess
            }
            if (!progress.notificationsGranted) {
                return AndroidDestination.NotificationsAccess
            }
            return AndroidDestination.Home
        }
        return AndroidDestination.Connecting
    }

    fun route(destination: AndroidDestination, origin: Origin = Origin.Onboarding): String =
        when (destination) {
            AndroidDestination.Welcome -> Routes.Welcome
            AndroidDestination.Connecting -> Routes.connecting(origin)
            AndroidDestination.FocusAccess -> Routes.FocusAccess
            AndroidDestination.NotificationsAccess -> Routes.NotificationsAccess
            AndroidDestination.Home -> Routes.Home
        }

    /**
     * Start destination is computed once. A peer unpair (or a 401 expiry)
     * clears the pair while NavHost is already on Home/Settings; send the
     * user back to Welcome instead of leaving a stale status screen.
     *
     * Leave the pairing and local-unpair screens alone: Connecting is
     * reached after a scan *before* the pair is persisted, and Unpair
     * Confirm navigates itself once [PairSession.unpair] finishes. Resetting
     * those races the handshake (Mac pairs, phone shows Scan again) or
     * double-pops the graph and crashes.
     */
    fun shouldResetToWelcome(hasStoredPair: Boolean, route: String?): Boolean {
        if (hasStoredPair) {
            return false
        }
        val route = route ?: return false
        return !isOwnedWhileUnpaired(route)
    }

    private fun isOwnedWhileUnpaired(route: String): Boolean =
        route == Routes.Welcome ||
            route == Routes.UnpairConfirm ||
            route.startsWith("connect_to_mac/") ||
            route.startsWith("connecting/")
}
