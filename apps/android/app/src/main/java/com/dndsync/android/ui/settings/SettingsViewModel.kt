package com.dndsync.android.ui.settings

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dndsync.android.BuildConfig
import com.dndsync.android.pair.PairSession
import com.dndsync.android.sync.SyncSession
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SettingsViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val pairSession: PairSession,
    private val syncSession: SyncSession,
) : ViewModel() {
    private val nearbyGranted = MutableStateFlow(hasPermission(Manifest.permission.NEARBY_WIFI_DEVICES))
    private val notificationsGranted = MutableStateFlow(hasPermission(Manifest.permission.POST_NOTIFICATIONS))

    private val events = Channel<SettingsEvent>(Channel.BUFFERED)
    val eventFlow: Flow<SettingsEvent> = events.receiveAsFlow()

    val uiState: StateFlow<SettingsUiState> = combine(
        pairSession.ui,
        syncSession.lanUi,
        nearbyGranted,
        notificationsGranted,
    ) { cloud, lan, nearby, notifications ->
        SettingsUiState(
            peerDeviceName = cloud.macDeviceName.ifBlank { "Mac" },
            connected = lan.connected || cloud.joinSucceeded,
            nearbyGranted = nearby,
            notificationsGranted = notifications,
            debugDiagnosticsAvailable = BuildConfig.DEBUG,
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = SettingsUiState(debugDiagnosticsAvailable = BuildConfig.DEBUG),
    )

    fun refreshPermissions() {
        nearbyGranted.value = hasPermission(Manifest.permission.NEARBY_WIFI_DEVICES)
        notificationsGranted.value = hasPermission(Manifest.permission.POST_NOTIFICATIONS)
    }

    fun onNearbyPermissionResult(granted: Boolean) {
        nearbyGranted.value = granted
        syncSession.setNearbyGranted(granted)
    }

    fun onNotificationsPermissionResult(granted: Boolean) {
        notificationsGranted.value = granted
    }

    fun unpair() {
        pairSession.unpair(notifyPeer = true)
        viewModelScope.launch { events.send(SettingsEvent.Unpaired) }
    }

    private fun hasPermission(permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
}
