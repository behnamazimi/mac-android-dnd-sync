package com.dndsync.android.sync

import android.util.Log
import com.dndsync.android.BuildConfig

import com.dndsync.android.lan.LanUiState
import com.dndsync.android.pair.UnpairContext
import com.dndsync.proto.v1.CloudEnvelope
import com.dndsync.proto.v1.DndState
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Originate and apply DndState. Owns echo suppression and last-write-wins
 * across LAN and the wake-and-pull CloudEnvelope.
 */
class SyncSession(
    private val lan: SyncLan,
    private val cloud: SyncCloud,
    private val pair: SyncPairing,
    private val nowMs: () -> Long = { System.currentTimeMillis() },
    mainDispatcher: CoroutineDispatcher = Dispatchers.Main.immediate,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    var onApplyRemote: ((Boolean) -> Unit)? = null

    private val scope = CoroutineScope(SupervisorJob() + mainDispatcher)
    private val ioScope = CoroutineScope(SupervisorJob() + ioDispatcher)
    private val gate = LanSyncGate(nowMs)
    private val nearbyGranted = AtomicBoolean(false)
    private var originGeneration = 0
    private var currentOrigin: Origin? = null

    private class Origin(val generation: Int) {
        val cloudStarted = AtomicBoolean(false)
        var lanJob: Job? = null
        var cloudJob: Job? = null
    }

    val lanUi: StateFlow<LanUiState> = lan.ui

    init {
        wire()
    }

    fun onLocalFocusChange(on: Boolean) {
        gate.noteObserverEvent()
        gate.onLocalChange(on)
    }

    fun noteObserverEvent() {
        gate.noteObserverEvent()
    }

    fun onInboundState(state: DndState, viaLan: Boolean) {
        if (gate.onRemote(state)) {
            pair.persistLastSync(
                unixMs = state.unixMs,
                on = state.on,
                sender = state.sender,
                viaLan = viaLan,
            )
        }
    }

    fun onInboundUnpair(control: com.dndsync.proto.v1.PairControl) {
        pair.handleInboundUnpair(control)
    }

    fun onInboundEnvelope(envelope: CloudEnvelope) {
        val raw = envelope.ciphertext.toByteArray()
        val plaintext: ByteArray = if (pair.joined) {
            val opened = pair.open(raw)
            if (opened != null) {
                opened
            } else if (envelope.payloadKind == CloudEnvelopeCodec.PAYLOAD_PAIR_CONTROL) {
                return
            } else {
                pair.noteCloudError("decrypt failed")
                return
            }
        } else {
            raw
        }
        val control = PairControlFrames.decode(plaintext)
        if (envelope.payloadKind == CloudEnvelopeCodec.PAYLOAD_PAIR_CONTROL || control != null) {
            if (control != null) {
                onInboundUnpair(control)
            }
            return
        }
        val state = try {
            DndState.parseFrom(plaintext)
        } catch (_: Exception) {
            pair.noteCloudError("invalid inner DndState")
            return
        }
        if (state.version != Wire.PROTO_VERSION) {
            return
        }
        onInboundState(state, viaLan = false)
    }

    fun onInboundCommand(on: Boolean) {
        val state = DndState.newBuilder()
            .setVersion(Wire.PROTO_VERSION)
            .setOn(on)
            .setUnixMs(nowMs())
            .setSender(Wire.SENDER_MAC)
            .build()
        onInboundState(state, viaLan = false)
    }

    fun sendUnpair(context: UnpairContext) {
        if (context.pairId.isEmpty()) {
            return
        }
        val control = PairControlFrames.unpair(pairId = context.pairId)
        if (context.pairSecret.isEmpty() || context.forwarderUrl.isEmpty()) {
            if (nearbyGranted.get()) {
                runBlocking(ioDispatcher) { lan.deliverUnpair(control) }
            }
            return
        }
        // Finish the forwarder notify before returning. PairSession.unpair()
        // stops LAN as soon as this returns, and a missed push is the only
        // way an off-LAN Mac learns about unpair.
        postUnpairAndDelete(context, control)
        if (nearbyGranted.get()) {
            runBlocking(ioDispatcher) { lan.deliverUnpair(control) }
        }
    }

    fun setPairId(pairId: String) {
        lan.setPairId(pairId)
    }

    fun setNearbyGranted(granted: Boolean) {
        nearbyGranted.set(granted)
        syncTransport()
    }

    fun startLANIfJoined() {
        syncTransport()
    }

    fun stopLAN() {
        lan.stop()
        gate.reset()
    }

    private fun syncTransport() {
        if (pair.joined && nearbyGranted.get()) {
            lan.start()
        } else {
            lan.stop()
        }
    }

    private fun wire() {
        gate.onOriginate = { state ->
            if (pair.joined) {
                val previous = currentOrigin
                previous?.lanJob?.cancel()
                if (previous?.cloudStarted?.get() != true) {
                    previous?.cloudJob?.cancel()
                }
                val origin = Origin(++originGeneration)
                currentOrigin = origin
                origin.lanJob = scope.launch {
                    val nearby = nearbyGranted.get()
                    debug("flip on=${state.on} unix_ms=${state.unixMs} nearby=$nearby")
                    val acked = try {
                        if (nearby) lan.deliverState(state) else false
                    } catch (cancelled: CancellationException) {
                        throw cancelled
                    } catch (error: Exception) {
                        debug("lan deliver failed ${error.message}")
                        throw error
                    }
                    if (!isActive || origin.generation != originGeneration) {
                        debug("flip dropped stale unix_ms=${state.unixMs}")
                        return@launch
                    }
                    if (acked) {
                        debug("lan ack unix_ms=${state.unixMs}")
                        pair.persistLastSync(
                            unixMs = state.unixMs,
                            on = state.on,
                            sender = state.sender,
                            viaLan = true,
                        )
                        return@launch
                    }
                    debug("cloud fallback unix_ms=${state.unixMs}")
                    origin.cloudStarted.set(true)
                    origin.cloudJob = ioScope.launch {
                        postEnvelope(state)
                        if (origin.generation == originGeneration) {
                            pair.persistLastSync(
                                unixMs = state.unixMs,
                                on = state.on,
                                sender = state.sender,
                                viaLan = false,
                            )
                        }
                    }
                }
            }
        }
        gate.onApplyRemote = { on ->
            onApplyRemote?.invoke(on)
        }
        lan.inbound
            .onEach { state -> onInboundState(state, viaLan = true) }
            .launchIn(scope)
        lan.inboundUnpair
            .onEach { control -> onInboundUnpair(control) }
            .launchIn(scope)
    }

    private fun postEnvelope(state: DndState) {
        if (!pair.joined || pair.forwarderURL.isEmpty() || pair.pairSecret.isEmpty()) {
            debug("cloud post skipped joined=${pair.joined}")
            return
        }
        ioScope.launch {
            try {
                val ciphertext = pair.seal(state.toByteArray())
                val envelope = CloudEnvelopeCodec.make(
                    pair.pairId,
                    Wire.SENDER_ANDROID,
                    ciphertext,
                )
                cloud.postEnvelope(
                    pair.forwarderURL,
                    pair.pairId,
                    pair.pairSecret,
                    envelope.toByteArray(),
                )
                debug("cloud post ok unix_ms=${state.unixMs}")
                pair.noteCloudSuccess()
            } catch (error: Exception) {
                debug("cloud post failed ${error.message}")
                if (error is com.dndsync.android.cloud.ForwarderException.Unauthorized) {
                    pair.noteCloudUnauthorized()
                } else {
                    pair.noteCloudError(error.message ?: "request failed")
                }
            }
        }
    }

    private fun postUnpairAndDelete(
        context: UnpairContext,
        control: com.dndsync.proto.v1.PairControl,
    ) {
        try {
            val inner = control.toByteArray()
            val ciphertext = context.aesKey?.let {
                com.dndsync.android.pair.E2ECrypto.encrypt(inner, it)
            } ?: inner
            val envelope = CloudEnvelopeCodec.make(
                context.pairId,
                Wire.SENDER_ANDROID,
                ciphertext,
                CloudEnvelopeCodec.PAYLOAD_PAIR_CONTROL,
            )
            cloud.postEnvelope(
                context.forwarderUrl,
                context.pairId,
                context.pairSecret,
                envelope.toByteArray(),
            )
        } catch (_: Exception) {
        }
        try {
            cloud.deletePair(context.forwarderUrl, context.pairId, context.pairSecret)
        } catch (_: Exception) {
        }
    }

    private fun debug(message: String) {
        if (!BuildConfig.DEBUG) return
        try {
            Log.d("DndSync", "[DEBUG] $message")
        } catch (_: RuntimeException) {
            // JVM unit tests have no Android log.
        }
    }
}
