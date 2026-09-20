package com.dndsync.android.sync

import com.dndsync.proto.v1.PairControl

object PairControlFrames {
    const val VERSION = Wire.PAIR_CONTROL_VERSION

    fun unpair(pairId: String, unixMs: Long = System.currentTimeMillis()): PairControl =
        PairControl.newBuilder()
            .setVersion(VERSION)
            .setKind(PairControl.Kind.KIND_UNPAIR)
            .setPairId(pairId)
            .setUnixMs(unixMs)
            .build()

    fun decode(payload: ByteArray): PairControl? {
        val control = try {
            PairControl.parseFrom(payload)
        } catch (_: Exception) {
            return null
        }
        if (control.version != VERSION) {
            return null
        }
        if (control.kind != PairControl.Kind.KIND_UNPAIR) {
            return null
        }
        return control
    }

    fun matches(control: PairControl, pairId: String): Boolean =
        control.pairId.isEmpty() || control.pairId == pairId
}

object UnpairPolicy {
    fun shouldNotifyPeer(notifyPeer: Boolean, joined: Boolean): Boolean =
        notifyPeer && joined
}
