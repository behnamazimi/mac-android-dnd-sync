package com.dndsync.android.dnd

import android.app.NotificationManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DndApplyPolicyTest {
    @Test
    fun unknownIsSkip() {
        assertNull(DndApplyPolicy.binaryOn(NotificationManager.INTERRUPTION_FILTER_UNKNOWN))
        assertFalse(DndApplyPolicy.displayOn(NotificationManager.INTERRUPTION_FILTER_UNKNOWN))
    }

    @Test
    fun allIsOff() {
        assertEquals(false, DndApplyPolicy.binaryOn(NotificationManager.INTERRUPTION_FILTER_ALL))
        assertFalse(DndApplyPolicy.displayOn(NotificationManager.INTERRUPTION_FILTER_ALL))
    }

    @Test
    fun priorityIsOn() {
        assertEquals(true, DndApplyPolicy.binaryOn(NotificationManager.INTERRUPTION_FILTER_PRIORITY))
        assertTrue(DndApplyPolicy.displayOn(NotificationManager.INTERRUPTION_FILTER_PRIORITY))
    }

    @Test
    fun canApplyRequiresPolicyAndNotifications() {
        assertFalse(DndApplyPolicy.canApply(policyAccessGranted = false, notificationsGranted = true))
        assertFalse(DndApplyPolicy.canApply(policyAccessGranted = true, notificationsGranted = false))
        assertTrue(DndApplyPolicy.canApply(policyAccessGranted = true, notificationsGranted = true))
    }
}

class VetoIncidentTrackerTest {
    @Test
    fun notifiesOnceUntilCleared() {
        val veto = VetoIncidentTracker()
        assertTrue(veto.onVetoedOff())
        assertFalse(veto.onVetoedOff())
        veto.onRuleTurnedOn()
        assertTrue(veto.onVetoedOff())
    }

    @Test
    fun filterAllClearsIncident() {
        val veto = VetoIncidentTracker()
        assertTrue(veto.onVetoedOff())
        veto.onFilterAll()
        assertFalse(veto.vetoedOff)
        assertTrue(veto.onVetoedOff())
    }
}

class OffApplyPolicyTest {
    @Test
    fun stalePriorityCallbackDuringSettleIsNotAVeto() {
        assertFalse(
            OffApplyPolicy.shouldVetoAfterSettle(
                pendingOff = true,
                filter = NotificationManager.INTERRUPTION_FILTER_PRIORITY,
                settleElapsed = false,
            ),
        )
    }

    @Test
    fun stillPriorityAfterSettleIsAVeto() {
        assertTrue(
            OffApplyPolicy.shouldVetoAfterSettle(
                pendingOff = true,
                filter = NotificationManager.INTERRUPTION_FILTER_PRIORITY,
                settleElapsed = true,
            ),
        )
    }

    @Test
    fun allAfterSettleIsSuccess() {
        assertTrue(OffApplyPolicy.filterIsAll(NotificationManager.INTERRUPTION_FILTER_ALL))
        assertFalse(
            OffApplyPolicy.shouldVetoAfterSettle(
                pendingOff = true,
                filter = NotificationManager.INTERRUPTION_FILTER_ALL,
                settleElapsed = true,
            ),
        )
    }

    @Test
    fun notPendingNeverVetoes() {
        assertFalse(
            OffApplyPolicy.shouldVetoAfterSettle(
                pendingOff = false,
                filter = NotificationManager.INTERRUPTION_FILTER_PRIORITY,
                settleElapsed = true,
            ),
        )
    }

    @Test
    fun settleWindowIsLongerThanAHalfSecond() {
        assertTrue(OffApplyPolicy.EVALUATION_DELAY_MS > 500L)
    }
}
