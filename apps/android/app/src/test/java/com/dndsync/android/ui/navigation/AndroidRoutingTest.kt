package com.dndsync.android.ui.navigation

import org.junit.Assert.assertEquals
import org.junit.Test

class AndroidRoutingTest {
    @Test
    fun unpairedGoesToWelcome() {
        assertEquals(AndroidDestination.Welcome, AndroidRouting.destination(progress()))
    }

    @Test
    fun storedButNotJoinedGoesToConnecting() {
        assertEquals(
            AndroidDestination.Connecting,
            AndroidRouting.destination(progress(hasStoredPair = true)),
        )
    }

    @Test
    fun joinedWithoutPolicyGoesToFocusAccess() {
        assertEquals(
            AndroidDestination.FocusAccess,
            AndroidRouting.destination(progress(hasStoredPair = true, joined = true)),
        )
    }

    @Test
    fun joinedWithoutNotificationsGoesToNotificationsAccess() {
        assertEquals(
            AndroidDestination.NotificationsAccess,
            AndroidRouting.destination(
                progress(hasStoredPair = true, joined = true, policyAccessGranted = true),
            ),
        )
    }

    @Test
    fun completeLandsOnHome() {
        assertEquals(
            AndroidDestination.Home,
            AndroidRouting.destination(
                progress(
                    hasStoredPair = true,
                    joined = true,
                    policyAccessGranted = true,
                    notificationsGranted = true,
                    onboardingComplete = true,
                ),
            ),
        )
    }

    @Test
    fun completeIgnoresMissingNotifications() {
        assertEquals(
            AndroidDestination.Home,
            AndroidRouting.destination(
                progress(hasStoredPair = true, joined = true, onboardingComplete = true),
            ),
        )
    }

    @Test
    fun peerUnpairFromHomeResetsToWelcome() {
        assertEquals(true, AndroidRouting.shouldResetToWelcome(false, Routes.Home))
        assertEquals(true, AndroidRouting.shouldResetToWelcome(false, Routes.Settings))
        assertEquals(false, AndroidRouting.shouldResetToWelcome(false, Routes.Welcome))
        assertEquals(false, AndroidRouting.shouldResetToWelcome(false, Routes.connectToMac(Origin.Onboarding)))
        assertEquals(false, AndroidRouting.shouldResetToWelcome(true, Routes.Home))
    }

    private fun progress(
        hasStoredPair: Boolean = false,
        joined: Boolean = false,
        policyAccessGranted: Boolean = false,
        notificationsGranted: Boolean = false,
        onboardingComplete: Boolean = false,
    ) = OnboardingProgress(
        hasStoredPair = hasStoredPair,
        joined = joined,
        policyAccessGranted = policyAccessGranted,
        notificationsGranted = notificationsGranted,
        onboardingComplete = onboardingComplete,
    )
}
