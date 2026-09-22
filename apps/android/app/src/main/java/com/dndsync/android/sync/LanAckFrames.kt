package com.dndsync.android.sync

import com.dndsync.proto.v1.LanAck

object LanAckFrames {
    const val VERSION = Wire.LAN_ACK_VERSION

    fun make(unixMs: Long): LanAck =
        LanAck.newBuilder()
            .setVersion(VERSION)
            .setUnixMs(unixMs)
            .build()

    fun decode(payload: ByteArray): LanAck? {
        val ack = try {
            LanAck.parseFrom(payload)
        } catch (_: Exception) {
            return null
        }
        if (ack.version != VERSION) {
            return null
        }
        return ack
    }
}
