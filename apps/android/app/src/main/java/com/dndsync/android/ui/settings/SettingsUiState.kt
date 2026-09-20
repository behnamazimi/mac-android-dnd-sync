package com.dndsync.android.ui.settings

data class SettingsUiState(
    val peerDeviceName: String = "",
    val connected: Boolean = false,
    val nearbyGranted: Boolean = false,
    val notificationsGranted: Boolean = false,
    val debugDiagnosticsAvailable: Boolean = false,
)

sealed class SettingsEvent {
    data object Unpaired : SettingsEvent()
}
