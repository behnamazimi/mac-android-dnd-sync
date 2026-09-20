package com.dndsync.android.ui.home

enum class AttentionReason { FocusAccessRevoked, NoNetwork, PairingExpired, ApplyDropped }

sealed class HomeStatus {
    data object Synced : HomeStatus()
    data object Syncing : HomeStatus()
    data class NeedsAttention(val reason: AttentionReason) : HomeStatus()
    data object OffDidntApply : HomeStatus()
}

/**
 * Home's one status card has four states instead of four destinations (Principle E).
 * Precedence mirrors the pre-redesign `LastError.android` ordering, with the old
 * `OfflineToast` overlay folded in as a fifth reason under NeedsAttention rather than
 * a separate global banner (there's no destination for it in the approved flow).
 */
object HomeStatusResolver {
    fun from(
        policyAccessGranted: Boolean,
        networkSatisfied: Boolean,
        pairingExpired: Boolean,
        applyDropped: Boolean,
        vetoedOff: Boolean,
        applyingRemote: Boolean,
    ): HomeStatus = when {
        !policyAccessGranted -> HomeStatus.NeedsAttention(AttentionReason.FocusAccessRevoked)
        !networkSatisfied -> HomeStatus.NeedsAttention(AttentionReason.NoNetwork)
        pairingExpired -> HomeStatus.NeedsAttention(AttentionReason.PairingExpired)
        applyDropped -> HomeStatus.NeedsAttention(AttentionReason.ApplyDropped)
        vetoedOff -> HomeStatus.OffDidntApply
        applyingRemote -> HomeStatus.Syncing
        else -> HomeStatus.Synced
    }
}
