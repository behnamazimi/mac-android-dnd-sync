package com.dndsync.android.ui.diagnostics

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dndsync.android.dnd.DndApply
import com.dndsync.android.dnd.interruptionFilterName
import com.dndsync.android.pair.FcmTokenStore
import com.dndsync.android.pair.PairSession
import com.dndsync.android.sync.SyncSession
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

@HiltViewModel
class DiagnosticsViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val dndApply: DndApply,
    private val syncSession: SyncSession,
    private val pairSession: PairSession,
    private val tokens: FcmTokenStore,
) : ViewModel() {
    private val permissions = MutableStateFlow(readPermissions())

    val uiState: StateFlow<DiagnosticsUiState> = combine(
        dndApply.snapshot,
        syncSession.lanUi,
        pairSession.ui,
        tokens.tokenFlow,
        permissions,
    ) { snap, lan, cloud, token, perms ->
        DiagnosticsUiState(
            pairStatus = cloud.pairStatus,
            fcmRegistered = !token.isNullOrEmpty(),
            policyAccessGranted = snap.policyAccessGranted,
            notificationsGranted = perms.notifications,
            nearbyGranted = perms.nearby,
            cameraGranted = perms.camera,
            lanAdvertising = lan.advertising,
            lanBrowsing = lan.browsing,
            lanConnected = lan.connected,
            lastInboundSummary = lan.lastInboundSummary,
            lastLanError = lan.lastError,
            lastRegister = cloud.lastRegister,
            lastEnvelopePost = cloud.lastEnvelopePost,
            lastCloudError = cloud.lastCloudError,
            interruptionFilterName = interruptionFilterName(snap.interruptionFilter),
            ruleActive = snap.ruleActive,
            vetoedOff = snap.vetoedOff,
            lastRemoteCommand = snap.lastRemoteCommand,
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = DiagnosticsUiState(),
    )

    fun refreshPermissions() {
        permissions.value = readPermissions()
    }

    fun turnOn() = dndApply.apply(true)

    fun turnOff() = dndApply.apply(false)

    private fun readPermissions() = Permissions(
        notifications = hasPermission(Manifest.permission.POST_NOTIFICATIONS),
        nearby = hasPermission(Manifest.permission.NEARBY_WIFI_DEVICES),
        camera = hasPermission(Manifest.permission.CAMERA),
    )

    private fun hasPermission(permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

    private data class Permissions(val notifications: Boolean, val nearby: Boolean, val camera: Boolean)
}
