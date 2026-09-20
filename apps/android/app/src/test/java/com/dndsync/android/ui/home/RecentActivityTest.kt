package com.dndsync.android.ui.home

import com.dndsync.android.sync.Wire
import com.dndsync.android.ui.copy.ProductCopy
import org.junit.Assert.assertEquals
import org.junit.Test

class RecentActivityTest {
    @Test
    fun hasSyncIsFalseForZero() {
        assertEquals(false, RecentActivity.hasSync(0L))
        assertEquals(true, RecentActivity.hasSync(1L))
    }

    @Test
    fun stateLabelMatchesOnOff() {
        assertEquals(ProductCopy.DND_ON_SHORT, RecentActivity.stateLabel(true))
        assertEquals(ProductCopy.DND_OFF_SHORT, RecentActivity.stateLabel(false))
    }

    @Test
    fun actorLabelMapsThisPhoneAndTheMac() {
        assertEquals(ProductCopy.BY_THIS_PHONE, RecentActivity.actorLabel(Wire.SENDER_ANDROID))
        assertEquals(ProductCopy.BY_THE_MAC, RecentActivity.actorLabel(Wire.SENDER_MAC))
        // Unrecognized senders (should never happen, but don't crash the row) read as the Mac.
        assertEquals(ProductCopy.BY_THE_MAC, RecentActivity.actorLabel(""))
    }

    @Test
    fun lineMatchesMacCopyShape() {
        assertEquals(
            "On by ${ProductCopy.BY_THIS_PHONE}",
            RecentActivity.line(on = true, sender = Wire.SENDER_ANDROID),
        )
        assertEquals(
            "Off by ${ProductCopy.BY_THE_MAC}",
            RecentActivity.line(on = false, sender = Wire.SENDER_MAC),
        )
    }

    @Test
    fun peerLabelFallsBackToMac() {
        assertEquals("Mac", RecentActivity.peerLabel(""))
        assertEquals("Studio Mac", RecentActivity.peerLabel("Studio Mac"))
    }
}
