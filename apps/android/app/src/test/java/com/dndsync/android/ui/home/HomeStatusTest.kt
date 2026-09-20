package com.dndsync.android.ui.home

import org.junit.Assert.assertEquals
import org.junit.Test

class HomeStatusTest {
    private fun resolve(
        policyAccessGranted: Boolean = true,
        networkSatisfied: Boolean = true,
        pairingExpired: Boolean = false,
        applyDropped: Boolean = false,
        vetoedOff: Boolean = false,
        applyingRemote: Boolean = false,
    ): HomeStatus = HomeStatusResolver.from(
        policyAccessGranted = policyAccessGranted,
        networkSatisfied = networkSatisfied,
        pairingExpired = pairingExpired,
        applyDropped = applyDropped,
        vetoedOff = vetoedOff,
        applyingRemote = applyingRemote,
    )

    @Test
    fun defaultsToSynced() {
        assertEquals(HomeStatus.Synced, resolve())
    }

    @Test
    fun applyingRemoteShowsSyncing() {
        assertEquals(HomeStatus.Syncing, resolve(applyingRemote = true))
    }

    @Test
    fun vetoedOffWinsOverSyncing() {
        assertEquals(HomeStatus.OffDidntApply, resolve(vetoedOff = true, applyingRemote = true))
    }

    @Test
    fun applyDroppedWinsOverVetoedOff() {
        assertEquals(
            HomeStatus.NeedsAttention(AttentionReason.ApplyDropped),
            resolve(applyDropped = true, vetoedOff = true),
        )
    }

    @Test
    fun pairingExpiredWinsOverApplyDropped() {
        assertEquals(
            HomeStatus.NeedsAttention(AttentionReason.PairingExpired),
            resolve(pairingExpired = true, applyDropped = true),
        )
    }

    @Test
    fun noNetworkWinsOverPairingExpired() {
        assertEquals(
            HomeStatus.NeedsAttention(AttentionReason.NoNetwork),
            resolve(networkSatisfied = false, pairingExpired = true),
        )
    }

    @Test
    fun missingPolicyAccessWinsOverEverything() {
        assertEquals(
            HomeStatus.NeedsAttention(AttentionReason.FocusAccessRevoked),
            resolve(
                policyAccessGranted = false,
                networkSatisfied = false,
                pairingExpired = true,
                applyDropped = true,
                vetoedOff = true,
                applyingRemote = true,
            ),
        )
    }
}
