package com.dndsync.android.lan

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.dndsync.android.sync.LanAckFrames
import com.dndsync.android.sync.PairControlFrames
import com.dndsync.android.sync.SyncLan
import com.dndsync.proto.v1.DndState
import com.dndsync.proto.v1.PairControl
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.IOException
import java.net.Inet4Address
import java.net.InetSocketAddress
import java.net.Socket
import java.net.SocketTimeoutException
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume

@Singleton
class LanSyncService @Inject constructor(
    @ApplicationContext private val context: Context,
) : SyncLan {
    private val nsdManager = context.getSystemService(NsdManager::class.java)
    private val started = AtomicBoolean(false)
    private val resolveLock = Any()

    private val _ui = MutableStateFlow(LanUiState())
    override val ui: StateFlow<LanUiState> = _ui.asStateFlow()

    private val _inbound = MutableSharedFlow<DndState>(extraBufferCapacity = 16)
    override val inbound: SharedFlow<DndState> = _inbound.asSharedFlow()

    private val _inboundUnpair = MutableSharedFlow<PairControl>(extraBufferCapacity = 4)
    override val inboundUnpair: SharedFlow<PairControl> = _inboundUnpair.asSharedFlow()

    private var multicastLock: WifiManager.MulticastLock? = null
    private var resolvedMac: NsdServiceInfo? = null
    private var resolveWaiter: CancellableContinuation<NsdServiceInfo>? = null
    @Volatile private var pairId: String = LanConstants.PAIR_ID

    private val discoveryListener = object : NsdManager.DiscoveryListener {
        override fun onDiscoveryStarted(serviceType: String) {
            _ui.update { it.copy(browsing = true, lastError = null) }
        }

        override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
            _ui.update { it.copy(browsing = false, lastError = "NSD discover failed: $errorCode") }
        }

        override fun onDiscoveryStopped(serviceType: String) {
            _ui.update { it.copy(browsing = false) }
        }

        override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
            _ui.update { it.copy(lastError = "NSD stop discover failed: $errorCode") }
        }

        override fun onServiceFound(serviceInfo: NsdServiceInfo) {
            if (serviceInfo.serviceName == LanConstants.ANDROID_INSTANCE_NAME) {
                return
            }
            @Suppress("DEPRECATION")
            nsdManager.resolveService(serviceInfo, resolveListener)
        }

        override fun onServiceLost(serviceInfo: NsdServiceInfo) {
            if (resolvedMac?.serviceName == serviceInfo.serviceName) {
                resolvedMac = null
            }
        }
    }

    private val resolveListener = object : NsdManager.ResolveListener {
        override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
            _ui.update { it.copy(lastError = "NSD resolve failed: $errorCode") }
        }

        override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
            if (!isMatchingPeer(serviceInfo)) {
                return
            }
            publishResolved(serviceInfo)
        }
    }

    override fun start() {
        if (!started.compareAndSet(false, true)) {
            return
        }
        acquireMulticastLock()
        Handler(Looper.getMainLooper()).post {
            if (!started.get()) {
                return@post
            }
            try {
                nsdManager.discoverServices(
                    LanConstants.SERVICE_TYPE,
                    NsdManager.PROTOCOL_DNS_SD,
                    discoveryListener,
                )
            } catch (error: Exception) {
                _ui.update { it.copy(lastError = error.message) }
            }
        }
    }

    override fun stop() {
        if (!started.compareAndSet(true, false)) {
            return
        }
        resolvedMac = null
        synchronized(resolveLock) {
            resolveWaiter = null
        }
        Handler(Looper.getMainLooper()).post {
            try {
                nsdManager.stopServiceDiscovery(discoveryListener)
            } catch (_: IllegalArgumentException) {
            }
        }
        multicastLock?.let { lock ->
            if (lock.isHeld) {
                lock.release()
            }
        }
        multicastLock = null
        _ui.value = LanUiState()
    }

    override fun setPairId(id: String) {
        if (pairId == id) {
            return
        }
        pairId = id
        resolvedMac = null
        if (!started.get()) {
            return
        }
        Handler(Looper.getMainLooper()).post {
            try {
                nsdManager.stopServiceDiscovery(discoveryListener)
            } catch (_: IllegalArgumentException) {
            }
            try {
                nsdManager.discoverServices(
                    LanConstants.SERVICE_TYPE,
                    NsdManager.PROTOCOL_DNS_SD,
                    discoveryListener,
                )
            } catch (error: Exception) {
                _ui.update { it.copy(lastError = error.message) }
            }
        }
    }

    override suspend fun deliverState(state: DndState): Boolean =
        deliver(state.toByteArray(), state.unixMs)

    override suspend fun deliverUnpair(control: PairControl) {
        deliver(control.toByteArray(), ackUnixMs = null)
    }

    private suspend fun deliver(payload: ByteArray, ackUnixMs: Long?): Boolean {
        if (!started.get()) {
            return false
        }
        val framed = try {
            LengthPrefixedFramer.frame(payload)
        } catch (_: IllegalArgumentException) {
            return false
        }
        val startedAt = SystemClock.elapsedRealtime()
        val socketHolder = AtomicReference<Socket?>(null)
        return try {
            withContext(Dispatchers.IO) {
                withTimeoutOrNull(ATTEMPT_BUDGET_MS) {
                    val info = awaitResolved()
                    val remaining = (ATTEMPT_BUDGET_MS - (SystemClock.elapsedRealtime() - startedAt))
                        .coerceAtLeast(1)
                    val socket = Socket()
                    socketHolder.set(socket)
                    coroutineContext[kotlinx.coroutines.Job]?.invokeOnCompletion {
                        closeQuietly(socket)
                    }
                    exchange(socket, info, framed, ackUnixMs, remaining.toInt())
                } ?: false
            }
        } finally {
            closeQuietly(socketHolder.get())
        }
    }

    private suspend fun awaitResolved(): NsdServiceInfo = suspendCancellableCoroutine { cont ->
        synchronized(resolveLock) {
            val existing = resolvedMac?.takeIf { isMatchingPeer(it) }
            if (existing != null) {
                cont.resume(existing)
            } else {
                resolveWaiter = cont
                cont.invokeOnCancellation {
                    synchronized(resolveLock) {
                        if (resolveWaiter === cont) {
                            resolveWaiter = null
                        }
                    }
                }
            }
        }
    }

    private fun publishResolved(info: NsdServiceInfo) {
        val waiter: CancellableContinuation<NsdServiceInfo>?
        synchronized(resolveLock) {
            resolvedMac = info
            waiter = resolveWaiter
            resolveWaiter = null
        }
        if (waiter != null && waiter.isActive) {
            waiter.resume(info)
        }
    }

    private fun exchange(
        socket: Socket,
        info: NsdServiceInfo,
        framed: ByteArray,
        ackUnixMs: Long?,
        timeoutMs: Int,
    ): Boolean {
        val host = preferredHost(info) ?: run {
            _ui.update { it.copy(lastError = "resolved peer has no address") }
            return false
        }
        return try {
            socket.tcpNoDelay = true
            socket.connect(InetSocketAddress(host, info.port), timeoutMs)
            socket.soTimeout = timeoutMs
            _ui.update { it.copy(connected = true, lastError = null) }
            socket.getOutputStream().write(framed)
            socket.getOutputStream().flush()
            if (ackUnixMs == null) {
                try {
                    socket.shutdownOutput()
                } catch (_: IOException) {
                }
                try {
                    socket.setSoLinger(true, 2)
                } catch (_: Exception) {
                }
                true
            } else {
                readMatchingAck(socket, ackUnixMs)
            }
        } catch (error: Exception) {
            _ui.update { it.copy(connected = false, lastError = error.message) }
            false
        } finally {
            _ui.update { it.copy(connected = false) }
        }
    }

    private fun readMatchingAck(socket: Socket, unixMs: Long): Boolean {
        val accumulator = LengthPrefixedFramer.Accumulator()
        val buffer = ByteArray(4_096)
        val input = socket.getInputStream()
        while (true) {
            val n = try {
                input.read(buffer)
            } catch (_: SocketTimeoutException) {
                return false
            }
            if (n < 0) {
                return false
            }
            val frames = accumulator.append(buffer, n)
            for (payload in frames) {
                if (PairControlFrames.decode(payload) != null) {
                    continue
                }
                val ack = LanAckFrames.decode(payload) ?: continue
                if (ack.unixMs == unixMs) {
                    return true
                }
            }
        }
    }

    private fun isMatchingPeer(info: NsdServiceInfo): Boolean {
        if (info.serviceName == LanConstants.ANDROID_INSTANCE_NAME) {
            return false
        }
        val pair = info.attributes[LanConstants.PAIR_TXT_KEY]?.toString(Charsets.UTF_8)
        return pair == pairId
    }

    private fun preferredHost(info: NsdServiceInfo) =
        info.hostAddresses.firstOrNull { it is Inet4Address } ?: info.hostAddresses.firstOrNull()

    private fun acquireMulticastLock() {
        val wifi = context.getSystemService(WifiManager::class.java) ?: return
        multicastLock = wifi.createMulticastLock("dndsync-lan").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun closeQuietly(socket: Socket?) {
        if (socket == null) {
            return
        }
        try {
            socket.close()
        } catch (_: IOException) {
        }
    }

    private companion object {
        const val ATTEMPT_BUDGET_MS = 2_000L
    }
}
