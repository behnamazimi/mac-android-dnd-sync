package com.dndsync.android.sync

import com.dndsync.android.lan.LanUiState
import com.dndsync.proto.v1.DndState
import com.dndsync.proto.v1.PairControl
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class InMemorySyncLan : SyncLan {
    private val _ui = MutableStateFlow(LanUiState())
    override val ui: StateFlow<LanUiState> = _ui
    override val inbound = MutableSharedFlow<DndState>(extraBufferCapacity = 16)
    override val inboundUnpair = MutableSharedFlow<PairControl>(extraBufferCapacity = 4)
    val sent = mutableListOf<DndState>()
    val unpairs = mutableListOf<PairControl>()
    var started = false
    var lastPairId = ""
    var ack = false
    var hangDelivery = false
    private var hangGate: CompletableDeferred<Unit>? = null

    override fun setPairId(pairId: String) {
        lastPairId = pairId
    }

    override fun start() {
        started = true
    }

    override fun stop() {
        started = false
    }

    override suspend fun deliverState(state: DndState): Boolean {
        sent.add(state)
        if (hangDelivery) {
            val gate = CompletableDeferred<Unit>()
            hangGate = gate
            gate.await()
        }
        return ack
    }

    fun releaseDelivery() {
        hangGate?.complete(Unit)
        hangDelivery = false
    }

    override suspend fun deliverUnpair(control: PairControl) {
        unpairs.add(control)
    }
}

class InMemorySyncCloud : SyncCloud {
    val posts = mutableListOf<ByteArray>()
    var deleted = false

    override fun postEnvelope(baseUrl: String, pairId: String, secret: String, envelope: ByteArray) {
        posts.add(envelope)
    }

    override fun deletePair(baseUrl: String, pairId: String, secret: String) {
        deleted = true
    }
}

class FakeSyncPairing : SyncPairing {
    override var joined = false
    override var pairId = "dndsync-test"
    override var pairSecret = "secret"
    override var forwarderURL = "https://example.invalid"
    var lastSync: LastSync? = null
    var unpaired = false
    val cloudErrors = mutableListOf<String>()

    override fun seal(plaintext: ByteArray): ByteArray = plaintext
    override fun open(ciphertext: ByteArray): ByteArray? = ciphertext

    override fun persistLastSync(unixMs: Long, on: Boolean, sender: String, viaLan: Boolean) {
        lastSync = LastSync(unixMs, on, sender, viaLan)
    }

    override fun handleInboundUnpair(control: PairControl) {
        unpaired = true
        joined = false
    }

    override fun noteCloudUnauthorized() {
        cloudErrors.add("unauthorized")
    }

    override fun noteCloudError(message: String) {
        cloudErrors.add(message)
    }

    override fun noteCloudSuccess() {}

    data class LastSync(val unixMs: Long, val on: Boolean, val sender: String, val viaLan: Boolean)
}

fun dndState(on: Boolean, unixMs: Long, sender: String = Wire.SENDER_MAC): DndState =
    DndState.newBuilder()
        .setVersion(Wire.PROTO_VERSION)
        .setOn(on)
        .setUnixMs(unixMs)
        .setSender(sender)
        .build()
