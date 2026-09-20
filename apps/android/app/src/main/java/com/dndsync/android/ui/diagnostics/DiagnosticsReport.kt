package com.dndsync.android.ui.diagnostics

private const val EM_DASH = "—"

object DiagnosticsReport {
    fun lines(state: DiagnosticsUiState): List<String> = listOf(
        "Pair status: ${state.pairStatus}",
        "FCM: ${if (state.fcmRegistered) "registered" else EM_DASH}",
        "Policy access: ${state.policyAccessGranted}",
        "Notifications: ${state.notificationsGranted}",
        "Nearby: ${state.nearbyGranted}",
        "Camera: ${state.cameraGranted}",
        "LAN advertising: ${state.lanAdvertising}",
        "LAN browsing: ${state.lanBrowsing}",
        "LAN connected: ${state.lanConnected}",
        "Last inbound: ${state.lastInboundSummary ?: EM_DASH}",
        "Last LAN error: ${state.lastLanError ?: EM_DASH}",
        "Last register: ${state.lastRegister}",
        "Last envelope POST: ${state.lastEnvelopePost}",
        "Last cloud error: ${state.lastCloudError}",
        "Interruption filter: ${state.interruptionFilterName}",
        "Our rule: ${if (state.ruleActive) "on" else "off"}",
        "Vetoed off: ${state.vetoedOff}",
        "Last remote command: ${state.lastRemoteCommand ?: EM_DASH}",
    )

    fun build(state: DiagnosticsUiState): String = lines(state).joinToString("\n")
}
