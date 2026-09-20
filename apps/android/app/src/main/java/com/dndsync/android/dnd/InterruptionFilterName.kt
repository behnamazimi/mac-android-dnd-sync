package com.dndsync.android.dnd

import android.app.NotificationManager

fun interruptionFilterName(filter: Int): String = when (filter) {
    NotificationManager.INTERRUPTION_FILTER_ALL -> "INTERRUPTION_FILTER_ALL"
    NotificationManager.INTERRUPTION_FILTER_PRIORITY -> "INTERRUPTION_FILTER_PRIORITY"
    NotificationManager.INTERRUPTION_FILTER_NONE -> "INTERRUPTION_FILTER_NONE"
    NotificationManager.INTERRUPTION_FILTER_ALARMS -> "INTERRUPTION_FILTER_ALARMS"
    NotificationManager.INTERRUPTION_FILTER_UNKNOWN -> "INTERRUPTION_FILTER_UNKNOWN"
    else -> "UNKNOWN($filter)"
}
