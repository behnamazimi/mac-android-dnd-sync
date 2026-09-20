package com.dndsync.android.sync

import android.util.Base64
import com.dndsync.proto.v1.CloudEnvelope

object CloudEnvelopeCodec {
    const val PAYLOAD_DND_STATE = Wire.PAYLOAD_DND_STATE
    const val PAYLOAD_PAIR_CONTROL = Wire.PAYLOAD_PAIR_CONTROL

    fun make(
        pairId: String,
        sender: String,
        ciphertext: ByteArray,
        payloadKind: Int = PAYLOAD_DND_STATE,
    ): CloudEnvelope =
        CloudEnvelope.newBuilder()
            .setVersion(Wire.PROTO_VERSION)
            .setPairId(pairId)
            .setSender(sender)
            .setCiphertext(com.google.protobuf.ByteString.copyFrom(ciphertext))
            .setPayloadKind(payloadKind)
            .build()

    fun decode(bytes: ByteArray): CloudEnvelope? {
        val envelope = try {
            CloudEnvelope.parseFrom(bytes)
        } catch (_: Exception) {
            return null
        }
        if (envelope.version != Wire.PROTO_VERSION) {
            return null
        }
        return envelope
    }

    fun decodeBase64(value: String): CloudEnvelope? {
        val bytes = try {
            Base64.decode(value, Base64.DEFAULT)
        } catch (_: IllegalArgumentException) {
            return null
        }
        return decode(bytes)
    }
}
