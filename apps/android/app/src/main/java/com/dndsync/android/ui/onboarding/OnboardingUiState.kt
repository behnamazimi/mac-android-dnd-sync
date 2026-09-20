package com.dndsync.android.ui.onboarding

import com.dndsync.android.ui.designsystem.ConnectionPath

data class OnboardingUiState(
    val policyAccessGranted: Boolean = false,
    val dndAccessStillDenied: Boolean = false,
    val notificationsGranted: Boolean = false,
    val cameraGranted: Boolean = false,
    val cameraHardwareAvailable: Boolean = true,
    val cameraDenied: Boolean = false,
    val cameraUnavailable: Boolean = false,
    val joinSucceeded: Boolean = false,
    val waitingForFcm: Boolean = false,
    val fcmTokenUnavailable: Boolean = false,
    val pairError: String? = null,
    val peerDeviceName: String = "",
    val connectionPath: ConnectionPath = ConnectionPath.None,
)
