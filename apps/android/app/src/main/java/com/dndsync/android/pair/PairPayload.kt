package com.dndsync.android.pair

import org.json.JSONObject
import java.util.Base64

data class PairPayload(
    val forwarderUrl: String,
    val pairId: String,
    val pairSecret: String,
    val macE2ePublicKey: String,
    val macApnsToken: String,
    val macDeviceName: String = "",
) {
    companion object {
        fun parse(text: String): PairPayload {
            val json = text.trim()
            return try {
                parseObject(json)
            } catch (_: Exception) {
                parseKeys(json)
            }
        }

        fun looksLike(text: String): Boolean = try {
            parse(text)
            true
        } catch (_: Exception) {
            false
        }

        private fun parseObject(text: String): PairPayload {
            val json = JSONObject(text)
            return PairPayload(
                forwarderUrl = json.getString("forwarder_url"),
                pairId = json.getString("pair_id"),
                pairSecret = json.getString("pair_secret"),
                macE2ePublicKey = json.getString("mac_e2e_public_key"),
                macApnsToken = json.optString("mac_apns_token"),
                macDeviceName = if (json.isNull("mac_device_name")) {
                    ""
                } else {
                    json.optString("mac_device_name")
                },
            )
        }

        private fun parseKeys(json: String): PairPayload = PairPayload(
            forwarderUrl = requiredString(json, "forwarder_url"),
            pairId = requiredString(json, "pair_id"),
            pairSecret = requiredString(json, "pair_secret"),
            macE2ePublicKey = requiredString(json, "mac_e2e_public_key"),
            macApnsToken = optionalString(json, "mac_apns_token"),
            macDeviceName = optionalString(json, "mac_device_name"),
        )

        private fun requiredString(json: String, key: String): String {
            val value = optionalString(json, key)
            if (value.isEmpty()) {
                throw IllegalArgumentException("missing $key")
            }
            return value
        }

        private fun optionalString(json: String, key: String): String {
            val match = """"$key"\s*:\s*"((?:\\.|[^"\\])*)"""".toRegex().find(json) ?: return ""
            return unescapeJson(match.groupValues[1])
        }

        private fun unescapeJson(value: String): String {
            val out = StringBuilder(value.length)
            var i = 0
            while (i < value.length) {
                val c = value[i]
                if (c != '\\' || i + 1 >= value.length) {
                    out.append(c)
                    i += 1
                    continue
                }
                when (val next = value[i + 1]) {
                    '"' -> out.append('"')
                    '\\' -> out.append('\\')
                    '/' -> out.append('/')
                    'b' -> out.append('\u0008')
                    'f' -> out.append('\u000C')
                    'n' -> out.append('\n')
                    'r' -> out.append('\r')
                    't' -> out.append('\t')
                    'u' -> {
                        if (i + 5 >= value.length) {
                            out.append(next)
                            i += 2
                            continue
                        }
                        out.append(value.substring(i + 2, i + 6).toInt(16).toChar())
                        i += 6
                        continue
                    }
                    else -> out.append(next)
                }
                i += 2
            }
            return out.toString()
        }
    }

    fun macPublicKeyBytes(): ByteArray = decodeBase64(macE2ePublicKey)
}

internal fun decodeBase64(value: String): ByteArray {
    val compact = value.filterNot { it.isWhitespace() }
        .replace('-', '+')
        .replace('_', '/')
    val padded = when (compact.length % 4) {
        0 -> compact
        2 -> "$compact=="
        3 -> "$compact="
        else -> throw IllegalArgumentException("invalid base64")
    }
    return Base64.getDecoder().decode(padded)
}
