package com.dndsync.android.dnd

import android.app.NotificationManager

data class DndApplySnapshot(
    val policyAccessGranted: Boolean = false,
    val interruptionFilter: Int = NotificationManager.INTERRUPTION_FILTER_UNKNOWN,
    val ruleActive: Boolean = false,
    val vetoedOff: Boolean = false,
    val lastRemoteCommand: String? = null,
)
