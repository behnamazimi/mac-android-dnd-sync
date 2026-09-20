package com.dndsync.android.ui.home

import com.dndsync.android.sync.Wire
import com.dndsync.android.ui.copy.ProductCopy

/**
 * Pure formatting for one synced-event line. [HomeViewModel] builds the in-memory
 * trail (see [HomeViewModel] doc); this only turns one event into display strings.
 *
 * Tracks [sender] (not the LAN/cloud path): rows say who flipped Do Not Disturb,
 * not which path carried it — end users don't care whether a sync used Wi-Fi or
 * the cloud forwarder.
 */
data class SyncEvent(val unixMs: Long, val on: Boolean, val sender: String)

object RecentActivity {
    fun hasSync(unixMs: Long): Boolean = unixMs > 0L

    fun stateLabel(on: Boolean): String =
        if (on) ProductCopy.DND_ON_SHORT else ProductCopy.DND_OFF_SHORT

    fun actorLabel(sender: String): String =
        if (sender == Wire.SENDER_ANDROID) ProductCopy.BY_THIS_PHONE else ProductCopy.BY_THE_MAC

    fun line(on: Boolean, sender: String): String =
        "${stateLabel(on)} by ${actorLabel(sender)}"

    fun peerLabel(name: String): String = name.ifBlank { "Mac" }
}
