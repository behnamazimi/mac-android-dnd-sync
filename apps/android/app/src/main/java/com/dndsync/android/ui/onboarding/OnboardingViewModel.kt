package com.dndsync.android.ui.onboarding

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dndsync.android.dnd.DndApply
import com.dndsync.android.dnd.DndApplySnapshot
import com.dndsync.android.pair.CloudUiState
import com.dndsync.android.pair.PairSession
import com.dndsync.android.sync.SyncSession
import com.dndsync.android.ui.designsystem.ConnectionPath
import com.dndsync.android.ui.navigation.AndroidDestination
import com.dndsync.android.ui.navigation.AndroidRouting
import com.dndsync.android.ui.navigation.OnboardingProgress
import com.dndsync.android.ui.navigation.Origin
import com.dndsync.android.ui.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import javax.inject.Inject

private data class Grants(val notifications: Boolean, val camera: Boolean)

private data class Local(
    val openedDndSettings: Boolean = false,
    val cameraAsked: Boolean = false,
    val cameraUnavailable: Boolean = false,
)

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val dndApply: DndApply,
    private val syncSession: SyncSession,
    private val pairSession: PairSession,
    private val prefsStore: OnboardingPrefsStore,
) : ViewModel() {
    private val notificationsGranted = MutableStateFlow(hasPermission(Manifest.permission.POST_NOTIFICATIONS))
    private val cameraGranted = MutableStateFlow(hasPermission(Manifest.permission.CAMERA))
    private val cameraHardwareAvailable = context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA)

    private val local = MutableStateFlow(
        Local(
            cameraAsked = prefsStore.wasEverRequested(OnboardingPrefsStore.TrackedPermission.Camera),
            cameraUnavailable = !cameraHardwareAvailable,
        ),
    )

    val uiState: StateFlow<OnboardingUiState> = combine(
        dndApply.snapshot,
        combine(notificationsGranted, cameraGranted) { n, c -> Grants(n, c) },
        combine(pairSession.ui, syncSession.lanUi) { cloud, lan -> cloud to lan },
        local,
    ) { snap, grants, cloudAndLan, loc ->
        val (cloud, lan) = cloudAndLan
        toUiState(snap, grants, cloud, lan.connected, loc)
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = OnboardingUiState(cameraHardwareAvailable = cameraHardwareAvailable),
    )

    fun progress(): OnboardingProgress {
        val state = uiState.value
        return OnboardingProgress(
            hasStoredPair = pairSession.hasStoredPair,
            joined = state.joinSucceeded,
            policyAccessGranted = state.policyAccessGranted,
            notificationsGranted = state.notificationsGranted,
            onboardingComplete = prefsStore.isOnboardingComplete(),
        )
    }

    fun destination(): AndroidDestination = AndroidRouting.destination(progress())

    fun nextOnboardingRoute(origin: Origin = Origin.Onboarding): String {
        val dest = destination()
        if (dest == AndroidDestination.Home && !prefsStore.isOnboardingComplete()) {
            return Routes.AllSet
        }
        return AndroidRouting.route(dest, origin)
    }

    fun markOnboardingComplete() {
        prefsStore.markOnboardingComplete()
    }

    private fun toUiState(
        snap: DndApplySnapshot,
        grants: Grants,
        cloud: CloudUiState,
        lanConnected: Boolean,
        loc: Local,
    ) = OnboardingUiState(
        policyAccessGranted = snap.policyAccessGranted,
        dndAccessStillDenied = loc.openedDndSettings && !snap.policyAccessGranted,
        notificationsGranted = grants.notifications,
        cameraGranted = grants.camera,
        cameraHardwareAvailable = cameraHardwareAvailable,
        cameraDenied = loc.cameraAsked && !grants.camera,
        cameraUnavailable = loc.cameraUnavailable,
        joinSucceeded = cloud.joinSucceeded,
        waitingForFcm = cloud.waitingForFcm,
        fcmTokenUnavailable = false,
        pairError = cloud.pairError,
        peerDeviceName = cloud.macDeviceName.ifBlank { "Mac" },
        connectionPath = when {
            lanConnected -> ConnectionPath.Lan
            cloud.joinSucceeded -> ConnectionPath.Cloud
            else -> ConnectionPath.None
        },
    )

    fun onOpenedDndSettings() {
        local.update { it.copy(openedDndSettings = true) }
    }

    fun onNotificationsPermissionResult(granted: Boolean) {
        prefsStore.markRequested(OnboardingPrefsStore.TrackedPermission.Notifications)
        notificationsGranted.value = granted
    }

    fun onCameraPermissionResult(granted: Boolean) {
        prefsStore.markRequested(OnboardingPrefsStore.TrackedPermission.Camera)
        local.update { it.copy(cameraAsked = true) }
        cameraGranted.value = granted
    }

    fun onCameraUnavailable() {
        local.update { it.copy(cameraUnavailable = true) }
    }

    fun pastePayload(text: String) {
        pairSession.pastePayload(text)
    }

    fun onScannedPayload(text: String): Boolean {
        if (!pairSession.looksLikePayload(text)) {
            return false
        }
        pairSession.pastePayload(text)
        return true
    }

    private fun hasPermission(permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
}
