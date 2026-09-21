package com.dndsync.android.lan

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import com.dndsync.android.sync.PairControlFrames
import com.dndsync.android.sync.SyncLan
import com.dndsync.android.sync.Wire
import com.dndsync.proto.v1.DndState
import com.dndsync.proto.v1.PairControl
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.IOException
import java.net.Inet4Address
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.atomic.AtomicBoolean
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class LanSyncService @Inject constructor(
    @ApplicationContext private val context: Context,
) : SyncLan {
    private val nsdManager = context.getSystemService(NsdManager::class.java)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val started = AtomicBoolean(false)
    private val sessionLock = Any()

    private val _ui = MutableStateFlow(LanUiState())
    override val ui: StateFlow<LanUiState> = _ui.asStateFlow()

    private val _inbound = MutableSharedFlow<DndState>(extraBufferCapacity = 16)
    override val inbound: SharedFlow<DndState> = _inbound.asSharedFlow()

    private val _inboundUnpair = MutableSharedFlow<PairControl>(extraBufferCapacity = 4)
    override val inboundUnpair: SharedFlow<PairControl> = _inboundUnpair.asSharedFlow()

    private var multicastLock: WifiManager.MulticastLock? = null
    private var serverSocket: ServerSocket? = null
    private var session: Socket? = null
    private var resolvedMac: NsdServiceInfo? = null
    private var acceptJob: Job? = null
    private var reconnectJob: Job? = null
    @Volatile private var pairId: String = LanConstants.PAIR_ID

    private val registrationListener = object : NsdManager.RegistrationListener {
        override fun onServiceRegistered(serviceInfo: NsdServiceInfo) {
            _ui.update { it.copy(advertising = true, lastError = null) }
        }

        override fun onRegistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
            _ui.update { it.copy(advertising = false, lastError = "NSD register failed: $errorCode") }
        }

        override fun onServiceUnregistered(serviceInfo: NsdServiceInfo) {
            _ui.update { it.copy(advertising = false) }
        }

        override fun onUnregistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
            _ui.update { it.copy(lastError = "NSD unregister failed: $errorCode") }
        }
    }

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

        override fun onServiceLost(serviceInfo: NsdServiceInfo) = Unit
    }

    private val resolveListener = object : NsdManager.ResolveListener {
        override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
            _ui.update { it.copy(lastError = "NSD resolve failed: $errorCode") }
        }

        override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
            if (!isMatchingPeer(serviceInfo)) {
                return
            }
            resolvedMac = serviceInfo
            tryConnect(serviceInfo)
        }
    }

    override fun start() {
        if (!started.compareAndSet(false, true)) {
            return
        }
        acceptJob = scope.launch {
            acquireMulticastLock()
            val server = ServerSocket().apply {
                reuseAddress = true
                bind(InetSocketAddress(0))
            }
            serverSocket = server
            val info = NsdServiceInfo().apply {
                serviceName = LanConstants.ANDROID_INSTANCE_NAME
                serviceType = LanConstants.SERVICE_TYPE
                port = server.localPort
                setAttribute(LanConstants.PAIR_TXT_KEY, pairId)
            }
            Handler(Looper.getMainLooper()).post {
                if (!started.get()) {
                    return@post
                }
                nsdManager.registerService(
                    info,
                    NsdManager.PROTOCOL_DNS_SD,
                    registrationListener,
                )
                nsdManager.discoverServices(
                    LanConstants.SERVICE_TYPE,
                    NsdManager.PROTOCOL_DNS_SD,
                    discoveryListener,
                )
            }
            acceptLoop(server)
        }
    }

    override fun stop() {
        if (!started.compareAndSet(true, false)) {
            return
        }
        reconnectJob?.cancel()
        reconnectJob = null
        acceptJob?.cancel()
        acceptJob = null
        try {
            serverSocket?.close()
        } catch (_: IOException) {
        }
        serverSocket = null
        closeSession()
        resolvedMac = null
        Handler(Looper.getMainLooper()).post {
            try {
                nsdManager.unregisterService(registrationListener)
            } catch (_: IllegalArgumentException) {
            }
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
        if (!started.get()) {
            return
        }
        val server = serverSocket ?: return
        Handler(Looper.getMainLooper()).post {
            try {
                nsdManager.unregisterService(registrationListener)
            } catch (_: IllegalArgumentException) {
            }
            val info = NsdServiceInfo().apply {
                serviceName = LanConstants.ANDROID_INSTANCE_NAME
                serviceType = LanConstants.SERVICE_TYPE
                port = server.localPort
                setAttribute(LanConstants.PAIR_TXT_KEY, pairId)
            }
            nsdManager.registerService(
                info,
                NsdManager.PROTOCOL_DNS_SD,
                registrationListener,
            )
        }
    }

    override fun sendUnpairNow(control: PairControl) {
        val framed = try {
            LengthPrefixedFramer.frame(control.toByteArray())
        } catch (_: IllegalArgumentException) {
            return
        }
        synchronized(sessionLock) {
            val socket = session ?: return
            try {
                socket.getOutputStream().write(framed)
                socket.getOutputStream().flush()
                // Half-close so the peer still gets the frame after we `stop()`
                // and `close()` the socket on unpair.
                socket.shutdownOutput()
            } catch (error: IOException) {
                _ui.update { it.copy(lastError = error.message) }
            }
        }
    }

    override fun send(state: DndState) {
        scope.launch {
            val framed = try {
                LengthPrefixedFramer.frame(state.toByteArray())
            } catch (_: IllegalArgumentException) {
                return@launch
            }
            synchronized(sessionLock) {
                val socket = session ?: return@synchronized
                try {
                    socket.getOutputStream().write(framed)
                    socket.getOutputStream().flush()
                } catch (error: IOException) {
                    _ui.update { it.copy(lastError = error.message) }
                }
            }
        }
    }

    private fun acceptLoop(server: ServerSocket) {
        while (started.get() && !server.isClosed) {
            val incoming = try {
                server.accept()
            } catch (_: IOException) {
                break
            }
            incoming.tcpNoDelay = true
            if (!attach(incoming)) {
                try {
                    incoming.close()
                } catch (_: IOException) {
                }
            }
        }
    }

    private fun tryConnect(info: NsdServiceInfo) {
        scope.launch {
            if (currentSession() != null) {
                return@launch
            }
            val host = preferredHost(info) ?: run {
                _ui.update { it.copy(lastError = "resolved peer has no address") }
                return@launch
            }
            val socket = Socket()
            try {
                socket.tcpNoDelay = true
                socket.connect(InetSocketAddress(host, info.port), CONNECT_TIMEOUT_MS)
            } catch (error: IOException) {
                try {
                    socket.close()
                } catch (_: IOException) {
                }
                _ui.update { it.copy(lastError = "connect failed: ${error.message}") }
                scheduleReconnect()
                return@launch
            }
            if (!attach(socket)) {
                try {
                    socket.close()
                } catch (_: IOException) {
                }
            }
        }
    }

    private fun attach(socket: Socket): Boolean {
        synchronized(sessionLock) {
            if (session?.isClosed == false) {
                return false
            }
            session = socket
        }
        _ui.update { it.copy(connected = true, lastError = null) }
        scope.launch { readLoop(socket) }
        return true
    }

    private fun readLoop(socket: Socket) {
        val accumulator = LengthPrefixedFramer.Accumulator()
        val buffer = ByteArray(4_096)
        try {
            val input = socket.getInputStream()
            while (started.get() && !socket.isClosed) {
                val n = input.read(buffer)
                if (n < 0) {
                    break
                }
                val frames = accumulator.append(buffer, n)
                for (payload in frames) {
                    val control = PairControlFrames.decode(payload)
                    if (control != null) {
                        _inboundUnpair.tryEmit(control)
                        continue
                    }
                    val peeked = try {
                        DndState.parseFrom(payload)
                    } catch (_: Exception) {
                        continue
                    }
                    if (peeked.version != Wire.PROTO_VERSION) {
                        continue
                    }
                    _ui.update {
                        it.copy(
                            lastInboundSummary = inboundSummary(peeked),
                        )
                    }
                    _inbound.tryEmit(peeked)
                }
            }
            onDisconnected("disconnected")
        } catch (error: Exception) {
            onDisconnected(error.message ?: "read failed")
        }
    }

    private fun onDisconnected(reason: String) {
        closeSession()
        _ui.update { it.copy(connected = false, lastError = reason) }
        scheduleReconnect()
    }

    private fun scheduleReconnect() {
        val mac = resolvedMac ?: return
        reconnectJob?.cancel()
        reconnectJob = scope.launch {
            delay(RECONNECT_DELAY_MS)
            if (started.get() && currentSession() == null) {
                tryConnect(mac)
            }
        }
    }

    private fun currentSession(): Socket? = synchronized(sessionLock) {
        session?.takeUnless { it.isClosed }
    }

    private fun closeSession() {
        synchronized(sessionLock) {
            try {
                session?.let { socket ->
                    try {
                        // Unread inbound bytes make a default close() RST,
                        // which drops the unpair frame still in the send
                        // buffer. Linger until that frame is actually sent.
                        socket.setSoLinger(true, 2)
                    } catch (_: Exception) {
                    }
                    socket.close()
                }
            } catch (_: IOException) {
            }
            session = null
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

    private fun inboundSummary(state: DndState): String =
        "on=${state.on} unix_ms=${state.unixMs} sender=${state.sender}"

    private companion object {
        const val CONNECT_TIMEOUT_MS = 5_000
        const val RECONNECT_DELAY_MS = 1_000L
    }
}
