package com.dndsync.android.pair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Base64

class PairPayloadTest {
    @Test
    fun parsesMacSortedKeyJson() {
        val key = encodedPeerKey()
        val json =
            """{"forwarder_url":"https://example.invalid/v1","mac_apns_token":"abc+def/ghi=","mac_device_name":"Studio Mac","mac_e2e_public_key":"$key","pair_id":"dndsync-dev","pair_secret":"secret"}"""
        val parsed = PairPayload.parse(json)
        assertEquals("https://example.invalid/v1", parsed.forwarderUrl)
        assertEquals("dndsync-dev", parsed.pairId)
        assertEquals("Studio Mac", parsed.macDeviceName)
        assertEquals(32, parsed.macPublicKeyBytes().size)
    }

    @Test
    fun parsesEscapedSlashesAndNullDeviceName() {
        val key = encodedPeerKey()
        val json =
            """{"forwarder_url":"https:\/\/example.invalid","mac_apns_token":"abc","mac_e2e_public_key":"$key","pair_id":"dndsync-dev","pair_secret":"secret"}"""
        val parsed = PairPayload.parse(json)
        assertEquals("https://example.invalid", parsed.forwarderUrl)
        assertEquals("", parsed.macDeviceName)
        assertTrue(PairPayload.looksLike(json))
    }

    @Test
    fun decodesUrlSafeAndUnpaddedKey() {
        val raw = E2ECrypto.generateIdentity().publicKey
        val urlSafe = Base64.getUrlEncoder().withoutPadding().encodeToString(raw)
        val payload = PairPayload(
            forwarderUrl = "https://example.invalid",
            pairId = "dndsync-dev",
            pairSecret = "secret",
            macE2ePublicKey = urlSafe,
            macApnsToken = "abc",
        )
        assertTrue(payload.macPublicKeyBytes().contentEquals(raw))
    }

    private fun encodedPeerKey(): String =
        Base64.getEncoder().encodeToString(E2ECrypto.generateIdentity().publicKey)
}
