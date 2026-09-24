package com.dndsync.android.pair

import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.inject.Inject
import javax.inject.Singleton

data class StoredPair(
    val pairId: String,
    val pairSecret: String,
    val forwarderUrl: String,
    val privateKey: ByteArray,
    val publicKey: ByteArray,
    val peerPublicKey: ByteArray?,
    val joinSucceeded: Boolean = false,
    val macDeviceName: String = "",
    val lastSyncUnixMs: Long = 0L,
    val lastSyncOn: Boolean = false,
    val lastSyncSender: String = "",
    val lastSyncViaLan: Boolean = false,
    /** What this phone last registered with the forwarder; unchanged skips the PUT. */
    val registeredFingerprint: String = "",
    /** The forwarder rejected this code (401); don't re-join it on every start. */
    val joinRejected: Boolean = false,
)

@Singleton
class PairStore @Inject constructor(
    @PairPrefs private val prefs: SharedPreferences,
) : PairStoring {

    override fun load(): StoredPair? {
        val blob = prefs.getString(PREF_BLOB, null) ?: return null
        val iv = prefs.getString(PREF_IV, null) ?: return null
        return try {
            val json = JSONObject(
                String(unwrap(Base64.decode(blob, Base64.DEFAULT), Base64.decode(iv, Base64.DEFAULT))),
            )
            val peer = json.optString("peer_public_key")
            val joinSucceeded = if (json.has("join_succeeded")) {
                json.getBoolean("join_succeeded")
            } else {
                peer.isNotEmpty()
            }
            StoredPair(
                pairId = json.getString("pair_id"),
                pairSecret = json.getString("pair_secret"),
                forwarderUrl = json.getString("forwarder_url"),
                privateKey = Base64.decode(json.getString("private_key"), Base64.DEFAULT),
                publicKey = Base64.decode(json.getString("public_key"), Base64.DEFAULT),
                peerPublicKey = if (peer.isNullOrEmpty()) null else Base64.decode(peer, Base64.DEFAULT),
                joinSucceeded = joinSucceeded,
                macDeviceName = json.optString("mac_device_name"),
                lastSyncUnixMs = json.optLong("last_sync_unix_ms"),
                lastSyncOn = json.optBoolean("last_sync_on"),
                lastSyncSender = json.optString("last_sync_sender"),
                lastSyncViaLan = json.optBoolean("last_sync_via_lan"),
                registeredFingerprint = json.optString("registered_fingerprint"),
                joinRejected = json.optBoolean("join_rejected"),
            )
        } catch (_: Exception) {
            null
        }
    }

    override fun save(pair: StoredPair) {
        val json = JSONObject()
            .put("pair_id", pair.pairId)
            .put("pair_secret", pair.pairSecret)
            .put("forwarder_url", pair.forwarderUrl)
            .put("private_key", Base64.encodeToString(pair.privateKey, Base64.NO_WRAP))
            .put("public_key", Base64.encodeToString(pair.publicKey, Base64.NO_WRAP))
            .put(
                "peer_public_key",
                pair.peerPublicKey?.let { Base64.encodeToString(it, Base64.NO_WRAP) } ?: "",
            )
            .put("join_succeeded", pair.joinSucceeded)
            .put("mac_device_name", pair.macDeviceName)
            .put("last_sync_unix_ms", pair.lastSyncUnixMs)
            .put("last_sync_on", pair.lastSyncOn)
            .put("last_sync_sender", pair.lastSyncSender)
            .put("last_sync_via_lan", pair.lastSyncViaLan)
            .put("registered_fingerprint", pair.registeredFingerprint)
            .put("join_rejected", pair.joinRejected)
        val (ciphertext, iv) = wrap(json.toString().toByteArray(Charsets.UTF_8))
        prefs.edit()
            .putString(PREF_BLOB, Base64.encodeToString(ciphertext, Base64.NO_WRAP))
            .putString(PREF_IV, Base64.encodeToString(iv, Base64.NO_WRAP))
            .apply()
    }

    override fun clear() {
        prefs.edit().remove(PREF_BLOB).remove(PREF_IV).apply()
    }

    private fun wrap(plaintext: ByteArray): Pair<ByteArray, ByteArray> {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, wrapKey())
        return cipher.doFinal(plaintext) to cipher.iv
    }

    private fun unwrap(ciphertext: ByteArray, iv: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, wrapKey(), GCMParameterSpec(128, iv))
        return cipher.doFinal(ciphertext)
    }

    private fun wrapKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = store.getKey(KEY_ALIAS, null) as? SecretKey
        if (existing != null) {
            return existing
        }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    private companion object {
        const val KEY_ALIAS = "dndsync_pair_wrap"
        const val PREF_BLOB = "pair_blob"
        const val PREF_IV = "pair_iv"
    }
}
