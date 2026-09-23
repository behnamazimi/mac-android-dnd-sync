package com.dndsync.android.pair

import com.dndsync.android.cloud.ForwarderException
import com.dndsync.android.sync.PairControlFrames
import com.dndsync.android.sync.SyncPairing
import com.dndsync.android.sync.UnpairPolicy
import com.dndsync.android.sync.Wire
import com.dndsync.proto.v1.PairControl
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Create, restore, QR, join, unpair. Owns E2E keys.
 * `joined` is forwarder join success, not merely key presence.
 * Callers never hold [aesKey]; they use [seal] / [open].
 */
class PairSession(
    private val forwarder: PairForwarder,
    private val store: PairStoring,
    private val token: () -> String?,
    ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
    private val postToMain: (() -> Unit) -> Unit = { it() },
) : SyncPairing {
    var onNotifyPeerUnpair: ((UnpairContext) -> Unit)? = null
    var onPairIdChange: ((String) -> Unit)? = null
    var onCleared: (() -> Unit)? = null
    var onJoined: (() -> Unit)? = null

    private val scope = CoroutineScope(SupervisorJob() + ioDispatcher)

    private val _ui = MutableStateFlow(CloudUiState())
    val ui: StateFlow<CloudUiState> = _ui.asStateFlow()

    private var storedPairId = ""
    private var storedPairSecret = ""
    private var storedForwarderUrl = ""
    private var macDeviceName = ""
    private var identity = E2ECrypto.generateIdentity()
    private var peerPublicKey: ByteArray? = null
    private var aesKey: ByteArray? = null
    @Volatile private var joinSucceeded = false

    override val joined: Boolean get() = joinSucceeded
    val hasStoredPair: Boolean
        get() = try {
            store.load() != null
        } catch (_: Exception) {
            false
        }
    override val pairId: String get() = storedPairId
    override val pairSecret: String get() = storedPairSecret
    override val forwarderURL: String get() = storedForwarderUrl

    init {
        restore()
    }

    fun looksLikePayload(text: String): Boolean = PairPayload.looksLike(text)

    fun registerCurrentToken() {
        val current = token() ?: return
        registerToken(current)
    }

    fun registerToken(pushToken: String) {
        if (joinSucceeded) {
            registerDevice(pushToken)
            return
        }
        if (storedPairId.isNotEmpty() && storedPairSecret.isNotEmpty() && storedForwarderUrl.isNotEmpty()) {
            joinCurrent(pushToken)
        }
    }

    fun pastePayload(text: String) {
        scope.launch {
            val payload = try {
                PairPayload.parse(text)
            } catch (_: Exception) {
                _ui.update { it.copy(pairError = CloudCopy.BAD_PAYLOAD) }
                return@launch
            }
            try {
                acceptPayload(payload)
            } catch (_: Exception) {
                _ui.update { it.copy(pairError = CloudCopy.BAD_PAYLOAD) }
            }
        }
    }

    private fun acceptPayload(payload: PairPayload) {
        val saved = store.load()
        when (
            PairJoinPolicy.action(
                storedPairId = saved?.pairId,
                storedJoined = saved?.joinSucceeded == true,
                incomingPairId = payload.pairId,
            )
        ) {
            PairJoinPolicy.Action.AlreadyJoined -> {
                _ui.update {
                    it.copy(
                        pairError = null,
                        joinSucceeded = true,
                        waitingForFcm = false,
                        pairStatus = "E2E ready",
                        pairingExpired = false,
                    )
                }
                return
            }
            PairJoinPolicy.Action.JoinExistingIdentity -> Unit
            PairJoinPolicy.Action.ReplaceAndJoin -> {
                identity = E2ECrypto.generateIdentity()
            }
        }
        storedPairId = payload.pairId
        storedPairSecret = payload.pairSecret
        storedForwarderUrl = payload.forwarderUrl
        macDeviceName = payload.macDeviceName
        val peer = payload.macPublicKeyBytes()
        peerPublicKey = peer
        aesKey = E2ECrypto.deriveAesKey(identity.privateKey, peer)
        joinSucceeded = false
        persist(joinSucceeded = false)
        postToMain { onPairIdChange?.invoke(storedPairId) }
        val pushToken = token()
        if (pushToken.isNullOrEmpty()) {
            _ui.update {
                it.copy(
                    pairStatus = "payload stored; waiting for FCM token",
                    forwarderUrl = storedForwarderUrl,
                    pairId = storedPairId,
                    macDeviceName = macDeviceName,
                    lastCloudError = CloudCopy.EM_DASH,
                    pairError = null,
                    waitingForFcm = true,
                    joinSucceeded = false,
                    pairingExpired = false,
                )
            }
            return
        }
        joinCurrent(pushToken)
    }

    fun unpair(notifyPeer: Boolean = true) {
        val context = unpairContext()
        if (context != null && UnpairPolicy.shouldNotifyPeer(notifyPeer, joinSucceeded)) {
            onNotifyPeerUnpair?.invoke(context)
        } else if (context != null) {
            scope.launch {
                try {
                    forwarder.deletePair(context.forwarderUrl, context.pairId, context.pairSecret)
                } catch (_: Exception) {
                }
            }
        }
        clearLocalPair()
    }

    override fun handleInboundUnpair(control: PairControl) {
        if (!joinSucceeded) {
            return
        }
        if (!PairControlFrames.matches(control, storedPairId)) {
            return
        }
        unpair(notifyPeer = false)
    }

    override fun seal(plaintext: ByteArray): ByteArray {
        val key = aesKey ?: return plaintext
        return E2ECrypto.encrypt(plaintext, key)
    }

    override fun open(ciphertext: ByteArray): ByteArray? {
        val key = aesKey ?: return ciphertext
        return try {
            E2ECrypto.decrypt(ciphertext, key)
        } catch (_: Exception) {
            null
        }
    }

    override fun persistLastSync(unixMs: Long, on: Boolean, sender: String, viaLan: Boolean) {
        val existing = store.load() ?: return
        store.save(
            existing.copy(
                lastSyncUnixMs = unixMs,
                lastSyncOn = on,
                lastSyncSender = sender,
                lastSyncViaLan = viaLan,
            ),
        )
        _ui.update {
            it.copy(
                lastSyncUnixMs = unixMs,
                lastSyncOn = on,
                lastSyncSender = sender,
                lastSyncViaLan = viaLan,
            )
        }
    }

    override fun noteCloudSuccess() {
        _ui.update {
            it.copy(
                lastEnvelopePost = "204",
                lastCloudError = CloudCopy.EM_DASH,
                pairingExpired = false,
            )
        }
    }

    override fun noteCloudError(message: String) {
        _ui.update { it.copy(lastCloudError = message) }
    }

    override fun noteCloudUnauthorized() {
        val wasJoined = joinSucceeded
        _ui.update {
            it.copy(
                lastCloudError = CloudCopy.PAIRING_EXPIRED,
                pairingExpired = true,
            )
        }
        if (wasJoined) {
            postToMain { unpair(notifyPeer = false) }
        }
    }

    fun unpairContext(): UnpairContext? {
        if (storedPairId.isEmpty() || storedPairSecret.isEmpty() || storedForwarderUrl.isEmpty()) {
            return null
        }
        return UnpairContext(
            pairId = storedPairId,
            pairSecret = storedPairSecret,
            forwarderUrl = storedForwarderUrl,
            aesKey = aesKey,
        )
    }

    private fun restore() {
        val saved = store.load()
        if (saved == null) {
            _ui.update {
                CloudUiState(
                    pairStatus = "not paired",
                    lastCloudError = CloudCopy.EM_DASH,
                )
            }
            return
        }
        storedPairId = saved.pairId
        storedPairSecret = saved.pairSecret
        storedForwarderUrl = saved.forwarderUrl
        macDeviceName = saved.macDeviceName
        identity = E2ECrypto.Identity(saved.privateKey, saved.publicKey)
        peerPublicKey = saved.peerPublicKey
        saved.peerPublicKey?.let { peer ->
            aesKey = E2ECrypto.deriveAesKey(identity.privateKey, peer)
        }
        joinSucceeded = saved.joinSucceeded
        onPairIdChange?.invoke(storedPairId)
        _ui.update {
            it.copy(
                forwarderUrl = storedForwarderUrl,
                pairId = storedPairId,
                joinSucceeded = joinSucceeded,
                waitingForFcm = !joinSucceeded,
                pairStatus = if (joinSucceeded) "E2E ready" else "waiting to join",
                macDeviceName = saved.macDeviceName,
                lastSyncUnixMs = saved.lastSyncUnixMs,
                lastSyncOn = saved.lastSyncOn,
                lastSyncSender = saved.lastSyncSender,
                lastSyncViaLan = saved.lastSyncViaLan,
            )
        }
        if (!joinSucceeded) {
            val pushToken = token()
            if (!pushToken.isNullOrEmpty()) {
                joinCurrent(pushToken)
            }
        } else {
            token()?.let { registerDevice(it) }
        }
    }

    private fun registerDevice(pushToken: String) {
        if (storedForwarderUrl.isEmpty() || storedPairSecret.isEmpty()) {
            return
        }
        scope.launch {
            try {
                forwarder.registerDevice(
                    baseUrl = storedForwarderUrl,
                    pairId = storedPairId,
                    secret = storedPairSecret,
                    sender = Wire.SENDER_ANDROID,
                    platform = Wire.PLATFORM_FCM,
                    token = pushToken,
                    e2ePublicKey = E2ECrypto.publicKeyB64(identity.publicKey),
                )
                _ui.update {
                    it.copy(
                        lastRegister = "204",
                        lastCloudError = CloudCopy.EM_DASH,
                        forwarderUrl = storedForwarderUrl,
                        pairingExpired = false,
                    )
                }
            } catch (error: Exception) {
                _ui.update {
                    it.copy(
                        lastRegister = "failed",
                        lastCloudError = productCloudError(error),
                        forwarderUrl = storedForwarderUrl,
                        pairingExpired = error.isUnauthorized(),
                    )
                }
                if (error.isUnauthorized()) {
                    noteCloudUnauthorized()
                }
            }
        }
    }

    private fun joinCurrent(pushToken: String) {
        scope.launch {
            try {
                forwarder.joinPair(
                    baseUrl = storedForwarderUrl,
                    pairId = storedPairId,
                    secret = storedPairSecret,
                    sender = Wire.SENDER_ANDROID,
                    platform = Wire.PLATFORM_FCM,
                    token = pushToken,
                    e2ePublicKey = E2ECrypto.publicKeyB64(identity.publicKey),
                )
                joinSucceeded = true
                persist(joinSucceeded = true)
                _ui.update {
                    it.copy(
                        pairStatus = "E2E ready",
                        lastRegister = "join 204",
                        lastCloudError = CloudCopy.EM_DASH,
                        forwarderUrl = storedForwarderUrl,
                        pairId = storedPairId,
                        macDeviceName = macDeviceName,
                        joinSucceeded = true,
                        waitingForFcm = false,
                        pairError = null,
                        pairingExpired = false,
                    )
                }
                postToMain { onJoined?.invoke() }
            } catch (error: Exception) {
                joinSucceeded = false
                try {
                    persist(joinSucceeded = false)
                } catch (_: Exception) {
                }
                _ui.update {
                    it.copy(
                        pairStatus = "join failed",
                        lastRegister = "join failed",
                        lastCloudError = productCloudError(error),
                        forwarderUrl = storedForwarderUrl,
                        pairId = storedPairId,
                        joinSucceeded = false,
                        waitingForFcm = false,
                        pairError = if (error.isUnauthorized()) {
                            CloudCopy.PAIRING_CODE_REJECTED
                        } else {
                            CloudCopy.JOIN_FAILED
                        },
                        pairingExpired = error.isUnauthorized(),
                        macDeviceName = macDeviceName,
                    )
                }
            }
        }
    }

    private fun clearLocalPair() {
        store.clear()
        identity = E2ECrypto.generateIdentity()
        aesKey = null
        peerPublicKey = null
        joinSucceeded = false
        storedPairId = ""
        storedPairSecret = ""
        storedForwarderUrl = ""
        macDeviceName = ""
        _ui.update {
            CloudUiState(
                pairStatus = "cleared",
                lastCloudError = CloudCopy.EM_DASH,
            )
        }
        onPairIdChange?.invoke("")
        onCleared?.invoke()
    }

    private fun persist(joinSucceeded: Boolean) {
        val existing = try {
            store.load()
        } catch (_: Exception) {
            null
        }
        store.save(
            StoredPair(
                pairId = storedPairId,
                pairSecret = storedPairSecret,
                forwarderUrl = storedForwarderUrl,
                privateKey = identity.privateKey,
                publicKey = identity.publicKey,
                peerPublicKey = peerPublicKey,
                joinSucceeded = joinSucceeded,
                macDeviceName = macDeviceName.ifBlank { existing?.macDeviceName.orEmpty() },
                lastSyncUnixMs = existing?.lastSyncUnixMs ?: 0L,
                lastSyncOn = existing?.lastSyncOn ?: false,
                lastSyncSender = existing?.lastSyncSender.orEmpty(),
                lastSyncViaLan = existing?.lastSyncViaLan ?: false,
            ),
        )
    }

    private fun productCloudError(error: Exception): String {
        if (error.isUnauthorized()) {
            return CloudCopy.PAIRING_EXPIRED
        }
        return error.message ?: "request failed"
    }
}

private fun Exception.isUnauthorized(): Boolean = this is ForwarderException.Unauthorized
