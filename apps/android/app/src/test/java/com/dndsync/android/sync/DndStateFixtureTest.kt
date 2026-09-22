package com.dndsync.android.sync

import com.dndsync.proto.v1.DndState
import com.dndsync.proto.v1.PairControl
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DndStateFixtureTest {
    @Test
    fun decodesGoldenFixture() {
        val bytes = javaClass.getResourceAsStream("/dnd_state_v1.binpb")!!.readBytes()
        val state = DndState.parseFrom(bytes)
        assertEquals(1, state.version)
        assertTrue(state.on)
        assertEquals(1_700_000_000_000L, state.unixMs)
        assertEquals("mac", state.sender)
    }

    @Test
    fun decodesGoldenCloudEnvelope() {
        val bytes = javaClass.getResourceAsStream("/cloud_envelope_v1.binpb")!!.readBytes()
        val envelope = com.dndsync.proto.v1.CloudEnvelope.parseFrom(bytes)
        assertEquals(1, envelope.version)
        assertEquals("dndsync-dev", envelope.pairId)
        assertEquals("mac", envelope.sender)
        val inner = DndState.parseFrom(envelope.ciphertext)
        assertEquals(1, inner.version)
        assertTrue(inner.on)
        assertEquals(1_700_000_000_000L, inner.unixMs)
        assertEquals("mac", inner.sender)
    }

    @Test
    fun dropsNonV1CloudEnvelope() {
        val envelope = com.dndsync.proto.v1.CloudEnvelope.newBuilder()
            .setVersion(2)
            .setPairId("dndsync-dev")
            .setSender("mac")
            .build()
        assertEquals(null, CloudEnvelopeCodec.decode(envelope.toByteArray()))
    }

    @Test
    fun pairControlVersionIsDroppedAsDndState() {
        val control = PairControlFrames.unpair("dndsync-dev")
        val asState = DndState.parseFrom(control.toByteArray())
        assertEquals(PairControlFrames.VERSION, asState.version)
    }

    @Test
    fun pairControlRoundTripUnpair() {
        val control = PairControlFrames.unpair("dndsync-dev", unixMs = 1_700_000_000_000L)
        val decoded = PairControlFrames.decode(control.toByteArray())
        assertEquals(PairControl.Kind.KIND_UNPAIR, decoded!!.kind)
        assertEquals("dndsync-dev", decoded.pairId)
        assertEquals(1_700_000_000_000L, decoded.unixMs)
        assertEquals(true, PairControlFrames.matches(decoded, "dndsync-dev"))
        assertEquals(false, PairControlFrames.matches(decoded, "other"))
    }

    @Test
    fun cloudEnvelopeCarriesPairControlKind() {
        val control = PairControlFrames.unpair("dndsync-dev")
        val envelope = CloudEnvelopeCodec.make(
            "dndsync-dev",
            "android",
            control.toByteArray(),
            CloudEnvelopeCodec.PAYLOAD_PAIR_CONTROL,
        )
        assertEquals(CloudEnvelopeCodec.PAYLOAD_PAIR_CONTROL, envelope.payloadKind)
        assertEquals(PairControl.Kind.KIND_UNPAIR, PairControlFrames.decode(envelope.ciphertext.toByteArray())!!.kind)
    }

    @Test
    fun lanAckRoundTripDoesNotDecodeAsStateOrUnpair() {
        val ack = LanAckFrames.make(1_700_000_000_000L)
        val bytes = ack.toByteArray()
        val decoded = LanAckFrames.decode(bytes)
        assertEquals(LanAckFrames.VERSION, decoded!!.version)
        assertEquals(1_700_000_000_000L, decoded.unixMs)
        assertEquals(null, PairControlFrames.decode(bytes))
        val asState = DndState.parseFrom(bytes)
        assertEquals(LanAckFrames.VERSION, asState.version)
        val state = dndState(on = true, unixMs = 1_700_000_000_000L, sender = Wire.SENDER_ANDROID)
        assertEquals(null, LanAckFrames.decode(state.toByteArray()))
    }
}

class UnpairPolicyTest {
    @Test
    fun inboundDoesNotNotifyPeer() {
        org.junit.Assert.assertFalse(UnpairPolicy.shouldNotifyPeer(notifyPeer = false, joined = true))
    }

    @Test
    fun localJoinedNotifiesPeer() {
        org.junit.Assert.assertTrue(UnpairPolicy.shouldNotifyPeer(notifyPeer = true, joined = true))
    }

    @Test
    fun unpairedLocalDoesNotNotify() {
        org.junit.Assert.assertFalse(UnpairPolicy.shouldNotifyPeer(notifyPeer = true, joined = false))
    }
}
