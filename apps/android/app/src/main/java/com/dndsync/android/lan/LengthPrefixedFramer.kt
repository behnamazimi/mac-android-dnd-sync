package com.dndsync.android.lan

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

object LengthPrefixedFramer {
    fun frame(payload: ByteArray): ByteArray {
        require(payload.size <= LanConstants.MAX_FRAME_BYTES) {
            "payload too large: ${payload.size}"
        }
        return ByteBuffer.allocate(4 + payload.size)
            .order(ByteOrder.BIG_ENDIAN)
            .putInt(payload.size)
            .put(payload)
            .array()
    }

    class Accumulator {
        private val buffer = ByteArrayOutputStream()

        fun append(chunk: ByteArray, length: Int = chunk.size): List<ByteArray> {
            buffer.write(chunk, 0, length)
            val data = buffer.toByteArray()
            val frames = mutableListOf<ByteArray>()
            var offset = 0
            while (data.size - offset >= 4) {
                val payloadLen = ByteBuffer.wrap(data, offset, 4)
                    .order(ByteOrder.BIG_ENDIAN)
                    .int
                if (payloadLen < 0 || payloadLen > LanConstants.MAX_FRAME_BYTES) {
                    throw IllegalArgumentException("frame too large: $payloadLen")
                }
                if (data.size - offset < 4 + payloadLen) {
                    break
                }
                val start = offset + 4
                val end = start + payloadLen
                frames += data.copyOfRange(start, end)
                offset = end
            }
            buffer.reset()
            if (offset < data.size) {
                buffer.write(data, offset, data.size - offset)
            }
            return frames
        }
    }
}
