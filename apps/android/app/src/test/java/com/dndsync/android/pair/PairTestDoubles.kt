package com.dndsync.android.pair

class InMemoryPairStore : PairStoring {
    var stored: StoredPair? = null

    override fun load(): StoredPair? = stored
    override fun save(pair: StoredPair) {
        stored = pair
    }
    override fun clear() {
        stored = null
    }
}

class FakePairForwarder : PairForwarder {
    var joined = false
    var registered = false
    var deleted = false
    var envelopes = 0
    var error: Exception? = null

    override fun registerDevice(
        baseUrl: String,
        pairId: String,
        secret: String,
        sender: String,
        platform: String,
        token: String,
        e2ePublicKey: String?,
    ) {
        error?.let { throw it }
        registered = true
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
        error?.let { throw it }
        joined = true
    }

    override fun postEnvelope(baseUrl: String, pairId: String, secret: String, envelope: ByteArray) {
        error?.let { throw it }
        envelopes += 1
    }

    override fun deletePair(baseUrl: String, pairId: String, secret: String) {
        error?.let { throw it }
        deleted = true
    }
}
