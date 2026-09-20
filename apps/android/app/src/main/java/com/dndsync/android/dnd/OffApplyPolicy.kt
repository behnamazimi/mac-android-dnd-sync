package com.dndsync.android.dnd

import android.app.NotificationManager

/**
 * When to treat a remote off as vetoed. Android 15 Modes often keeps the
 * interruption filter at PRIORITY for well over 500ms after we deactivate
 * our AutomaticZenRule, and may also broadcast a stale non-ALL filter the
 * moment the rule state changes. Veto only after that settle window, never
 * on the in-flight callback.
 */
object OffApplyPolicy {
    const val EVALUATION_DELAY_MS = 1_500L
    const val APPLYING_REMOTE_TIMEOUT_MS = 6_000L

    fun filterIsAll(filter: Int): Boolean =
        filter == NotificationManager.INTERRUPTION_FILTER_ALL

    /**
     * @param settleElapsed true only after [EVALUATION_DELAY_MS], never on
     * the interruption-filter callback that fires when we deactivate the rule.
     */
    fun shouldVetoAfterSettle(
        pendingOff: Boolean,
        filter: Int,
        settleElapsed: Boolean,
    ): Boolean = pendingOff && settleElapsed && !filterIsAll(filter)
}
