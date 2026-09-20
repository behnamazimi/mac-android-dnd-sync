package com.dndsync.android.dnd

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onStart
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DndSystemObserver @Inject constructor(
    @ApplicationContext private val context: Context,
    private val notificationManager: NotificationManager,
) {
    val interruptionFilter: Flow<Int> = broadcastFlow(
        NotificationManager.ACTION_INTERRUPTION_FILTER_CHANGED,
    )
        .map { notificationManager.currentInterruptionFilter }
        .onStart { emit(notificationManager.currentInterruptionFilter) }
        .distinctUntilChanged()

    val interruptionFilterChanges: Flow<Int> = broadcastFlow(
        NotificationManager.ACTION_INTERRUPTION_FILTER_CHANGED,
    )
        .map { notificationManager.currentInterruptionFilter }
        .distinctUntilChanged()

    val policyAccessGranted: Flow<Boolean> = broadcastFlow(
        NotificationManager.ACTION_NOTIFICATION_POLICY_ACCESS_GRANTED_CHANGED,
    )
        .map { notificationManager.isNotificationPolicyAccessGranted }
        .onStart { emit(notificationManager.isNotificationPolicyAccessGranted) }
        .distinctUntilChanged()

    fun currentInterruptionFilter(): Int = notificationManager.currentInterruptionFilter

    fun isPolicyAccessGranted(): Boolean = notificationManager.isNotificationPolicyAccessGranted

    private fun broadcastFlow(action: String): Flow<Unit> = callbackFlow {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                trySend(Unit)
            }
        }
        context.registerReceiver(
            receiver,
            IntentFilter(action),
            Context.RECEIVER_NOT_EXPORTED,
        )
        awaitClose { context.unregisterReceiver(receiver) }
    }
}
