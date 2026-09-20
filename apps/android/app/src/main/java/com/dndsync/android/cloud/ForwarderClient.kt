package com.dndsync.android.cloud

import com.dndsync.android.pair.PairForwarder
import com.dndsync.android.sync.SyncCloud
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

open class ForwarderException(message: String) : IOException(message) {
    class Unauthorized(body: String = "") : ForwarderException(
        "HTTP 401${if (body.isEmpty()) "" else ": $body"}",
    )

    class Http(val code: Int, body: String = "") : ForwarderException(
        "HTTP $code${if (body.isEmpty()) "" else ": $body"}",
    )

    class MissingUrl : ForwarderException("missing forwarder URL")
}

data class ForwarderDevice(
    val sender: String,
    val e2ePublicKey: String,
)

@Singleton
class ForwarderClient @Inject constructor() : PairForwarder, SyncCloud {
    private val client = OkHttpClient.Builder()
        .callTimeout(TIMEOUT_SEC, TimeUnit.SECONDS)
        .connectTimeout(TIMEOUT_SEC, TimeUnit.SECONDS)
        .readTimeout(TIMEOUT_SEC, TimeUnit.SECONDS)
        .writeTimeout(TIMEOUT_SEC, TimeUnit.SECONDS)
        .retryOnConnectionFailure(false)
        .build()

    override fun registerDevice(
        baseUrl: String,
        pairId: String,
        secret: String,
        sender: String,
        platform: String,
        token: String,
        e2ePublicKey: String?,
    ) {
        val body = JSONObject()
            .put("sender", sender)
            .put("platform", platform)
            .put("token", token)
        if (!e2ePublicKey.isNullOrEmpty()) {
            body.put("e2e_public_key", e2ePublicKey)
        }
        execute(
            request(baseUrl, "/v1/pairs/$pairId/devices")
                .put(jsonBody(body))
                .header("Authorization", "Bearer $secret")
                .build(),
            setOf(204),
        )
    }

    override fun joinPair(
        baseUrl: String,
        pairId: String,
        secret: String,
        sender: String,
        platform: String,
        token: String,
        e2ePublicKey: String,
    ) {
        val body = JSONObject()
            .put("sender", sender)
            .put("platform", platform)
            .put("token", token)
            .put("e2e_public_key", e2ePublicKey)
        execute(
            request(baseUrl, "/v1/pairs/$pairId/join")
                .post(jsonBody(body))
                .header("Authorization", "Bearer $secret")
                .build(),
            setOf(204),
        )
    }

    fun listDevices(baseUrl: String, pairId: String, secret: String): List<ForwarderDevice> {
        val payload = execute(
            request(baseUrl, "/v1/pairs/$pairId/devices")
                .get()
                .header("Authorization", "Bearer $secret")
                .build(),
            setOf(200),
        )
        val devices = JSONObject(payload).optJSONArray("devices") ?: JSONArray()
        return buildList {
            for (i in 0 until devices.length()) {
                val item = devices.getJSONObject(i)
                add(
                    ForwarderDevice(
                        sender = item.getString("sender"),
                        e2ePublicKey = item.optString("e2e_public_key"),
                    ),
                )
            }
        }
    }

    override fun postEnvelope(baseUrl: String, pairId: String, secret: String, envelope: ByteArray) {
        execute(
            request(baseUrl, "/v1/pairs/$pairId/envelopes")
                .post(envelope.toRequestBody(PROTOBUF))
                .header("Authorization", "Bearer $secret")
                .build(),
            setOf(204),
        )
    }

    override fun deletePair(baseUrl: String, pairId: String, secret: String) {
        execute(
            request(baseUrl, "/v1/pairs/$pairId")
                .delete()
                .header("Authorization", "Bearer $secret")
                .build(),
            setOf(204),
        )
    }

    private fun request(baseUrl: String, path: String): Request.Builder {
        if (baseUrl.isEmpty()) {
            throw ForwarderException.MissingUrl()
        }
        val root = baseUrl.trimEnd('/')
        return Request.Builder().url("$root$path")
    }

    private fun jsonBody(body: JSONObject) =
        body.toString().toRequestBody(JSON)

    private fun execute(request: Request, expect: Set<Int>): String {
        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (response.code !in expect) {
                throw if (response.code == 401) {
                    ForwarderException.Unauthorized(body)
                } else {
                    ForwarderException.Http(response.code, body)
                }
            }
            return body
        }
    }

    companion object {
        private const val TIMEOUT_SEC = 8L
        private val JSON = "application/json; charset=utf-8".toMediaType()
        private val PROTOBUF = "application/protobuf".toMediaType()
    }
}
