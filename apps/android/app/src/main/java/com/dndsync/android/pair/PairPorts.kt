package com.dndsync.android.pair

interface PairForwarder {
    fun registerDevice(
        baseUrl: String,
        pairId: String,
        secret: String,
        sender: String,
        platform: String,
        token: String,
        e2ePublicKey: String?,
    )

    fun joinPair(
        baseUrl: String,
        pairId: String,
        secret: String,
        sender: String,
        platform: String,
        token: String,
        e2ePublicKey: String,
    )

    fun postEnvelope(baseUrl: String, pairId: String, secret: String, envelope: ByteArray)

    fun deletePair(baseUrl: String, pairId: String, secret: String)
}

interface PairStoring {
    fun load(): StoredPair?
    fun save(pair: StoredPair)
    fun clear()
}

data class UnpairContext(
    val pairId: String,
    val pairSecret: String,
    val forwarderUrl: String,
    val aesKey: ByteArray?,
)
