package com.dndsync.android.dnd

import android.app.NotificationManager

object DndApplyPolicy {
    fun binaryOn(filter: Int): Boolean? = when (filter) {
        NotificationManager.INTERRUPTION_FILTER_UNKNOWN -> null
        NotificationManager.INTERRUPTION_FILTER_ALL -> false
        else -> true
    }

    fun displayOn(filter: Int): Boolean = binaryOn(filter) ?: false

    fun canApply(policyAccessGranted: Boolean, notificationsGranted: Boolean): Boolean =
        policyAccessGranted && notificationsGranted
}
