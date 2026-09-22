package com.dndsync.android.net

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Whether the system default network exists. Home maps false to the No-network card.
 *
 * [ConnectivityManager.activeNetwork] is often still null at process start, even
 * on Wi-Fi. Treating that miss as offline latches the banner until the process
 * dies. The [ConnectivityManager.NetworkCallback] is the live source; [refresh]
 * may only confirm online.
 */
@Singleton
class NetworkPathMonitor @Inject constructor(
    @ApplicationContext context: Context,
) {
    private val connectivity = context.getSystemService(ConnectivityManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private var defaultNetwork: Network? = null
    private val _satisfied = MutableStateFlow(true)
    val satisfied: StateFlow<Boolean> = _satisfied.asStateFlow()

    private val goOffline = Runnable {
        if (defaultNetwork == null) _satisfied.value = false
    }

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            defaultNetwork = network
            publish()
        }

        override fun onLost(network: Network) {
            if (defaultNetwork != network) return
            defaultNetwork = null
            publish()
        }

        override fun onUnavailable() {
            defaultNetwork = null
            publish()
        }

        override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
            defaultNetwork = network
            publish()
        }
    }

    init {
        connectivity.registerDefaultNetworkCallback(callback, handler)
        handler.post { publish() }
    }

    /** Foreground re-check. A null getter is unknown, not offline. */
    fun refresh() {
        handler.post {
            val current = connectivity.activeNetwork ?: return@post
            defaultNetwork = current
            publish()
        }
    }

    private fun publish() {
        if (defaultNetwork != null) {
            handler.removeCallbacks(goOffline)
            _satisfied.value = true
            return
        }
        if (!_satisfied.value) return
        handler.removeCallbacks(goOffline)
        handler.postDelayed(goOffline, OFFLINE_GRACE_MS)
    }

    private companion object {
        /** Same grace as the Mac path monitor. */
        const val OFFLINE_GRACE_MS = 2_000L
    }
}
