package com.dndsync.android.dnd

import android.os.Handler
import android.os.Looper
import com.dndsync.android.pair.FcmTokenStore
import com.dndsync.android.pair.PairSession
import com.dndsync.android.sync.CloudEnvelopeCodec
import com.dndsync.android.sync.SyncSession
import com.dndsync.android.sync.Wire
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class DndFcmService : FirebaseMessagingService() {
    @Inject
    lateinit var tokens: FcmTokenStore

    @Inject
    lateinit var pairSession: PairSession

    @Inject
    lateinit var syncSession: SyncSession

    @Inject
    lateinit var dndApply: DndApply

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMessageReceived(message: RemoteMessage) {
        val encoded = message.data[Wire.FCM_ENVELOPE_B64]
        if (!encoded.isNullOrEmpty()) {
            val envelope = CloudEnvelopeCodec.decodeBase64(encoded) ?: return
            mainHandler.post { syncSession.onInboundEnvelope(envelope) }
            return
        }
        val command = message.data[Wire.FCM_COMMAND] ?: return
        val active = when (command) {
            Wire.FCM_COMMAND_ON -> true
            Wire.FCM_COMMAND_OFF -> false
            else -> return
        }
        mainHandler.post {
            dndApply.recordRemoteCommand(command)
            syncSession.onInboundCommand(active)
        }
    }

    @Suppress("OVERRIDE_DEPRECATION")
    override fun onNewToken(token: String) {
        mainHandler.post {
            tokens.set(token)
            pairSession.registerToken(token)
        }
    }
}
