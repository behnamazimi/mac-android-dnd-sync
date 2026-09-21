package com.dndsync.android.pair

import com.dndsync.android.cloud.ForwarderException
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Base64

class PairSessionTests {
    @Test
    fun pasteThenJoinSetsJoined() {
        val forwarder = FakePairForwarder()
        val store = InMemoryPairStore()
        val session = session(forwarder, store, token = { "fcm-token" })

        session.pastePayload(payloadJson())

        assertTrue(session.joined)
        assertTrue(forwarder.joined)
        assertEquals("dndsync-abc", session.pairId)
        assertNotNull(store.stored)
        assertTrue(store.stored!!.joinSucceeded)
    }

    @Test
    fun unpairClearsJoined() {
        val forwarder = FakePairForwarder()
        val store = InMemoryPairStore()
        val session = session(forwarder, store, token = { "fcm-token" })
        session.pastePayload(payloadJson())
        assertTrue(session.joined)

        session.unpair(notifyPeer = false)

        assertFalse(session.joined)
        assertFalse(session.hasStoredPair)
    }

    @Test
    fun unpairNotifiesPeerWhenJoined() {
        val session = session(FakePairForwarder(), InMemoryPairStore(), token = { "fcm-token" })
        session.pastePayload(payloadJson())
        var notified: UnpairContext? = null
        session.onNotifyPeerUnpair = { notified = it }

        session.unpair(notifyPeer = true)

        assertEquals("dndsync-abc", notified?.pairId)
        assertEquals("secret", notified?.pairSecret)
        assertFalse(session.joined)
        assertFalse(session.hasStoredPair)
    }

    @Test
    fun restoreFromStore() {
        val mac = E2ECrypto.generateIdentity()
        val phone = E2ECrypto.generateIdentity()
        val store = InMemoryPairStore()
        store.stored = StoredPair(
            pairId = "dndsync-abc",
            pairSecret = "secret",
            forwarderUrl = "https://example.invalid",
            privateKey = phone.privateKey,
            publicKey = phone.publicKey,
            peerPublicKey = mac.publicKey,
            joinSucceeded = true,
            lastSyncUnixMs = 42,
            lastSyncOn = true,
            lastSyncSender = "mac",
            lastSyncViaLan = true,
        )
        val session = session(FakePairForwarder(), store, token = { "token" })

        assertTrue(session.joined)
        assertEquals("dndsync-abc", session.pairId)
        assertEquals(42L, session.ui.value.lastSyncUnixMs)
        assertTrue(session.ui.value.lastSyncViaLan)
    }

    @Test
    fun sealOpenRoundTripWhenJoined() {
        val session = session(FakePairForwarder(), InMemoryPairStore(), token = { "fcm-token" })
        session.pastePayload(payloadJson())
        val plain = "hello".toByteArray()
        val sealed = session.seal(plain)
        val opened = session.open(sealed)
        assertTrue(opened.contentEquals(plain))
    }

    @Test
    fun looksLikePayloadRejectsGarbage() {
        val session = session(FakePairForwarder(), InMemoryPairStore(), token = { null })
        assertFalse(session.looksLikePayload("not-json"))
        assertTrue(session.looksLikePayload(payloadJson()))
    }

    @Test
    fun pasteInvalidPeerKeySetsError() {
        val session = session(FakePairForwarder(), InMemoryPairStore(), token = { "fcm-token" })
        session.pastePayload(
            """{"forwarder_url":"https://example.invalid","pair_id":"dndsync-abc","pair_secret":"secret","mac_e2e_public_key":"YQ==","mac_apns_token":"apns"}""",
        )
        assertFalse(session.joined)
        assertEquals(CloudCopy.BAD_PAYLOAD, session.ui.value.pairError)
    }

    @Test
    fun unauthorizedJoinDoesNotSetJoined() {
        val forwarder = FakePairForwarder().apply { error = ForwarderException.Unauthorized() }
        val session = session(forwarder, InMemoryPairStore(), token = { "fcm-token" })
        session.pastePayload(payloadJson())
        assertFalse(session.joined)
        assertEquals(CloudCopy.JOIN_FAILED, session.ui.value.pairError)
    }

    private fun session(
        forwarder: PairForwarder,
        store: PairStoring,
        token: () -> String?,
    ) = PairSession(
        forwarder = forwarder,
        store = store,
        token = token,
        ioDispatcher = Dispatchers.Unconfined,
        postToMain = { it() },
    )

    private fun payloadJson(): String {
        val mac = E2ECrypto.generateIdentity()
        val key = Base64.getEncoder().encodeToString(mac.publicKey)
        return """{"forwarder_url":"https://example.invalid","pair_id":"dndsync-abc","pair_secret":"secret","mac_e2e_public_key":"$key","mac_apns_token":"apns","mac_device_name":"Test Mac"}"""
    }
}
