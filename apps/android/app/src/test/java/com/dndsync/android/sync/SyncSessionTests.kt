package com.dndsync.android.sync

import com.dndsync.android.pair.UnpairContext
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SyncSessionTests {
    @Test
    fun localChangeWithoutNearbySendsCloudOnly() {
        val lan = InMemorySyncLan()
        val cloud = InMemorySyncCloud()
        val pair = FakeSyncPairing().apply { joined = true }
        var now = 1_000L
        val session = session(lan, cloud, pair) { now }

        session.onLocalFocusChange(true)

        assertTrue(lan.sent.isEmpty())
        assertEquals(1, cloud.posts.size)
        assertEquals(true, pair.lastSync?.on)
        assertEquals(false, pair.lastSync?.viaLan)
    }

    @Test
    fun nearbyAckSkipsCloud() {
        val lan = InMemorySyncLan().apply { ack = true }
        val cloud = InMemorySyncCloud()
        val pair = FakeSyncPairing().apply { joined = true }
        val session = session(lan, cloud, pair) { 1_000L }
        session.setNearbyGranted(true)

        session.onLocalFocusChange(true)

        assertEquals(1, lan.sent.size)
        assertTrue(lan.sent[0].on)
        assertTrue(cloud.posts.isEmpty())
        assertEquals(true, pair.lastSync?.viaLan)
    }

    @Test
    fun nearbyWithoutAckSendsCloud() {
        val lan = InMemorySyncLan().apply { ack = false }
        val cloud = InMemorySyncCloud()
        val pair = FakeSyncPairing().apply { joined = true }
        val session = session(lan, cloud, pair) { 1_000L }
        session.setNearbyGranted(true)

        session.onLocalFocusChange(true)

        assertEquals(1, lan.sent.size)
        assertEquals(1, cloud.posts.size)
        assertEquals(false, pair.lastSync?.viaLan)
    }

    @Test
    fun newerFlipCancelsPendingCloudFallback() {
        val lan = InMemorySyncLan().apply {
            hangDelivery = true
            ack = true
        }
        val cloud = InMemorySyncCloud()
        val pair = FakeSyncPairing().apply { joined = true }
        var now = 1_000L
        val session = session(lan, cloud, pair) { now }
        session.setNearbyGranted(true)

        session.onLocalFocusChange(true)
        assertEquals(1, lan.sent.size)
        assertTrue(cloud.posts.isEmpty())

        lan.hangDelivery = false
        now = 2_000L
        session.onLocalFocusChange(false)

        assertEquals(2, lan.sent.size)
        assertTrue(cloud.posts.isEmpty())
        assertEquals(false, pair.lastSync?.on)
        assertEquals(true, pair.lastSync?.viaLan)
    }

    @Test
    fun remoteApplyIsEchoSuppressed() {
        val cloud = InMemorySyncCloud()
        val pair = FakeSyncPairing().apply { joined = true }
        var now = 5_000L
        val applied = mutableListOf<Boolean>()
        val session = session(InMemorySyncLan(), cloud, pair) { now }
        session.onApplyRemote = { applied.add(it) }

        session.onInboundState(dndState(on = true, unixMs = 5_000), viaLan = true)
        assertEquals(listOf(true), applied)
        assertTrue(cloud.posts.isEmpty())

        now = 5_500
        session.onLocalFocusChange(true)
        assertTrue(cloud.posts.isEmpty())

        now = 6_500
        session.onLocalFocusChange(false)
        assertEquals(1, cloud.posts.size)
        assertEquals(false, pair.lastSync?.viaLan)
    }

    @Test
    fun lateObserverAfterRemoteDoesNotOriginateSameOn() {
        val cloud = InMemorySyncCloud()
        val pair = FakeSyncPairing().apply { joined = true }
        var now = 5_000L
        val session = session(InMemorySyncLan(), cloud, pair) { now }

        session.onInboundState(dndState(on = true, unixMs = 5_000, sender = Wire.SENDER_MAC), viaLan = true)
        assertEquals(Wire.SENDER_MAC, pair.lastSync?.sender)
        assertTrue(cloud.posts.isEmpty())

        now = 8_000
        session.onLocalFocusChange(true)
        assertTrue(cloud.posts.isEmpty())
        assertEquals(Wire.SENDER_MAC, pair.lastSync?.sender)

        session.onLocalFocusChange(false)
        assertEquals(1, cloud.posts.size)
        assertEquals(Wire.SENDER_ANDROID, pair.lastSync?.sender)
        assertEquals(false, pair.lastSync?.viaLan)
    }

    @Test
    fun olderUnixMsDropped() {
        val pair = FakeSyncPairing().apply { joined = true }
        val applied = mutableListOf<Boolean>()
        val session = session(InMemorySyncLan(), InMemorySyncCloud(), pair) { 10_000 }
        session.onApplyRemote = { applied.add(it) }

        session.onInboundState(dndState(on = true, unixMs = 8_000), viaLan = true)
        session.onInboundState(dndState(on = false, unixMs = 7_000), viaLan = true)

        assertEquals(listOf(true), applied)
        assertEquals(8_000L, pair.lastSync?.unixMs)
    }

    @Test
    fun notJoinedDoesNotOriginate() {
        val cloud = InMemorySyncCloud()
        val pair = FakeSyncPairing().apply { joined = false }
        val session = session(InMemorySyncLan(), cloud, pair) { 1_000 }

        session.onLocalFocusChange(true)
        assertTrue(cloud.posts.isEmpty())
        assertEquals(null, pair.lastSync)
    }

    @Test
    fun unpairFrameClearsPair() {
        val pair = FakeSyncPairing().apply { joined = true }
        val session = session(InMemorySyncLan(), InMemorySyncCloud(), pair)
        session.onInboundUnpair(PairControlFrames.unpair("dndsync-test"))
        assertTrue(pair.unpaired)
        assertFalse(pair.joined)
    }

    @Test
    fun sendUnpairWritesLanAndPostsThenDeletes() {
        val lan = InMemorySyncLan()
        val cloud = InMemorySyncCloud()
        val session = session(lan, cloud, FakeSyncPairing().apply { joined = true })
        session.setNearbyGranted(true)
        session.sendUnpair(
            UnpairContext(
                pairId = "dndsync-test",
                pairSecret = "secret",
                forwarderUrl = "https://example.invalid",
                aesKey = null,
            ),
        )
        assertEquals(1, lan.unpairs.size)
        assertEquals("dndsync-test", lan.unpairs[0].pairId)
        assertEquals(1, cloud.posts.size)
        assertTrue(cloud.deleted)
    }

    @Test
    fun sendUnpairStillSendsLanWithoutForwarder() {
        val lan = InMemorySyncLan()
        val cloud = InMemorySyncCloud()
        val session = session(lan, cloud, FakeSyncPairing())
        session.setNearbyGranted(true)
        session.sendUnpair(
            UnpairContext(
                pairId = "dndsync-test",
                pairSecret = "",
                forwarderUrl = "",
                aesKey = null,
            ),
        )
        assertEquals(1, lan.unpairs.size)
        assertTrue(cloud.posts.isEmpty())
        assertFalse(cloud.deleted)
    }

    @Test
    fun sendUnpairDoesNotReturnUntilCloudFinishes() {
        val gate = java.util.concurrent.CountDownLatch(1)
        val posts = mutableListOf<ByteArray>()
        val cloud = object : SyncCloud {
            var deleted = false
            override fun postEnvelope(baseUrl: String, pairId: String, secret: String, envelope: ByteArray) {
                gate.await(2, java.util.concurrent.TimeUnit.SECONDS)
                posts.add(envelope)
            }
            override fun deletePair(baseUrl: String, pairId: String, secret: String) {
                deleted = true
            }
        }
        val session = session(InMemorySyncLan(), cloud, FakeSyncPairing().apply { joined = true })
        val finished = java.util.concurrent.atomic.AtomicBoolean(false)
        val thread = Thread {
            session.sendUnpair(
                UnpairContext(
                    pairId = "dndsync-test",
                    pairSecret = "secret",
                    forwarderUrl = "https://example.invalid",
                    aesKey = null,
                ),
            )
            finished.set(true)
        }
        thread.start()
        Thread.sleep(50)
        assertFalse(finished.get())
        gate.countDown()
        thread.join(2_000)
        assertTrue(finished.get())
        assertTrue(cloud.deleted)
        assertEquals(1, posts.size)
    }

    @Test
    fun inboundPairControlEnvelopeClearsPair() {
        val pair = FakeSyncPairing().apply { joined = true }
        val session = session(InMemorySyncLan(), InMemorySyncCloud(), pair)
        val control = PairControlFrames.unpair("dndsync-test")
        val envelope = CloudEnvelopeCodec.make(
            "dndsync-test",
            Wire.SENDER_MAC,
            control.toByteArray(),
            CloudEnvelopeCodec.PAYLOAD_PAIR_CONTROL,
        )
        session.onInboundEnvelope(envelope)
        assertTrue(pair.unpaired)
        assertFalse(pair.joined)
    }

    @Test
    fun inboundCommandGoesThroughGate() {
        val cloud = InMemorySyncCloud()
        val pair = FakeSyncPairing().apply { joined = true }
        var now = 1_000L
        val applied = mutableListOf<Boolean>()
        val session = session(InMemorySyncLan(), cloud, pair) { now }
        session.onApplyRemote = { applied.add(it) }

        session.onInboundCommand(true)
        assertEquals(listOf(true), applied)

        now = 1_500
        session.onLocalFocusChange(true)
        assertTrue(cloud.posts.isEmpty())
    }

    private fun session(
        lan: SyncLan,
        cloud: SyncCloud,
        pair: SyncPairing,
        nowMs: () -> Long = { 1_000L },
    ) = SyncSession(
        lan = lan,
        cloud = cloud,
        pair = pair,
        nowMs = nowMs,
        mainDispatcher = Dispatchers.Unconfined,
        ioDispatcher = Dispatchers.Unconfined,
    )
}

class LanSyncGateTests {
    @Test
    fun echoWindowSuppressesLocalChange() {
        var now = 1_000L
        val gate = LanSyncGate { now }
        val originated = mutableListOf<Boolean>()
        val applied = mutableListOf<Boolean>()
        gate.onOriginate = { originated.add(it.on) }
        gate.onApplyRemote = { applied.add(it) }

        assertTrue(gate.onRemote(dndState(on = true, unixMs = 1_000, sender = "android")))
        assertEquals(listOf(true), applied)

        now = 1_500
        gate.noteObserverEvent()
        gate.onLocalChange(true)
        assertTrue(originated.isEmpty())

        now = 2_100
        gate.onLocalChange(false)
        assertEquals(listOf(false), originated)
    }

    @Test
    fun lateObserverMatchingRemoteDoesNotOriginate() {
        var now = 1_000L
        val gate = LanSyncGate { now }
        val originated = mutableListOf<Boolean>()
        gate.onOriginate = { originated.add(it.on) }

        assertTrue(gate.onRemote(dndState(on = true, unixMs = 1_000, sender = "mac")))

        now = 4_000
        gate.noteObserverEvent()
        gate.onLocalChange(true)
        assertTrue(originated.isEmpty())

        gate.onLocalChange(false)
        assertEquals(listOf(false), originated)
    }

    @Test
    fun lastWriteWinsDropsOlder() {
        val gate = LanSyncGate { 9_000 }
        val applied = mutableListOf<Boolean>()
        gate.onApplyRemote = { applied.add(it) }

        assertTrue(gate.onRemote(dndState(on = true, unixMs = 8_000, sender = "android")))
        assertFalse(gate.onRemote(dndState(on = false, unixMs = 7_000, sender = "android")))
        assertEquals(listOf(true), applied)
    }
}
