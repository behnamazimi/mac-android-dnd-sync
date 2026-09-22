package com.dndsync.android.sync

import com.dndsync.proto.v1.DndState
import com.dndsync.proto.v1.PairControl
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import com.dndsync.android.lan.LanUiState

interface SyncLan {
    val ui: StateFlow<LanUiState>
    val inbound: SharedFlow<DndState>
    val inboundUnpair: SharedFlow<PairControl>
    fun setPairId(pairId: String)
    fun start()
    fun stop()
    /** True when the Mac ACKs this state's `unix_ms` within the attempt budget. */
    suspend fun deliverState(state: DndState): Boolean
    /** Best-effort dial. The caller still posts the cloud unpair. */
    suspend fun deliverUnpair(control: PairControl)
}

interface SyncCloud {
    fun postEnvelope(baseUrl: String, pairId: String, secret: String, envelope: ByteArray)
    fun deletePair(baseUrl: String, pairId: String, secret: String)
}

interface SyncPairing {
    val joined: Boolean
    val pairId: String
    val pairSecret: String
    val forwarderURL: String
    fun seal(plaintext: ByteArray): ByteArray
    fun open(ciphertext: ByteArray): ByteArray?
    fun persistLastSync(unixMs: Long, on: Boolean, sender: String, viaLan: Boolean)
    fun handleInboundUnpair(control: PairControl)
    fun noteCloudUnauthorized()
    fun noteCloudError(message: String)
    fun noteCloudSuccess()
}
