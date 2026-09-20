package com.dndsync.android.pair

import com.dndsync.android.sync.Wire
import com.google.crypto.tink.subtle.AesGcmJce
import com.google.crypto.tink.subtle.Hkdf
import com.google.crypto.tink.subtle.X25519
import java.security.MessageDigest
import java.util.Base64

object E2ECrypto {
    private val hkdfInfo = Wire.HKDF_INFO.toByteArray(Charsets.UTF_8)

    data class Identity(
        val privateKey: ByteArray,
        val publicKey: ByteArray,
    )

    fun generateIdentity(): Identity {
        val privateKey = X25519.generatePrivateKey()
        return Identity(
            privateKey = privateKey,
            publicKey = X25519.publicFromPrivate(privateKey),
        )
    }

    fun deriveAesKey(privateKey: ByteArray, peerPublicKey: ByteArray): ByteArray {
        val shared = X25519.computeSharedSecret(privateKey, peerPublicKey)
        return Hkdf.computeHkdf("HMACSHA256", shared, ByteArray(0), hkdfInfo, 32)
    }

    fun encrypt(plaintext: ByteArray, aesKey: ByteArray): ByteArray {
        return AesGcmJce(aesKey).encrypt(plaintext, ByteArray(0))
    }

    fun decrypt(combined: ByteArray, aesKey: ByteArray): ByteArray {
        return AesGcmJce(aesKey).decrypt(combined, ByteArray(0))
    }

    fun publicKeyB64(publicKey: ByteArray): String =
        Base64.getEncoder().encodeToString(publicKey)

    fun sha256Hex(value: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(value.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }
}
