package com.dndsync.android.dnd

import android.content.Context
import com.dndsync.android.pair.FcmTokenStore
import com.dndsync.android.pair.PairSession
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FcmTokenBootstrapper @Inject constructor(
    @ApplicationContext private val context: Context,
    private val tokens: FcmTokenStore,
    private val pairSession: PairSession,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var attempt = 0
    private var inFlight = false

    fun start() {
        fetch()
    }

    @Suppress("DEPRECATION")
    private fun fetch() {
        if (FirebaseApp.getApps(context).isEmpty() || inFlight) {
            return
        }
        inFlight = true
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            inFlight = false
            if (task.isSuccessful) {
                attempt = 0
                task.result?.let { token ->
                    tokens.set(token)
                    pairSession.registerToken(token)
                }
            } else if (attempt < MAX_RETRIES) {
                attempt += 1
                scope.launch {
                    delay(RETRY_BACKOFF_MS * attempt)
                    fetch()
                }
            }
        }
    }

    private companion object {
        const val RETRY_BACKOFF_MS = 5_000L
        const val MAX_RETRIES = 3
    }
}
