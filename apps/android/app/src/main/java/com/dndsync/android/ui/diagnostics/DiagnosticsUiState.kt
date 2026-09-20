package com.dndsync.android.ui.diagnostics

/**
 * Backs the debug-only Diagnostics screen — pair status, permission bits, LAN/cloud
 * lines, raw filter text. Never pair ids, pair secrets, E2E keys, FCM tokens, or APNs
 * tokens (matches the product's own long-standing constraint, see AGENTS.md
 * "First run as a developer").
 */
data class DiagnosticsUiState(
    val pairStatus: String = "",
    val fcmRegistered: Boolean = false,
    val policyAccessGranted: Boolean = false,
    val notificationsGranted: Boolean = false,
    val nearbyGranted: Boolean = false,
    val cameraGranted: Boolean = false,
    val lanAdvertising: Boolean = false,
    val lanBrowsing: Boolean = false,
    val lanConnected: Boolean = false,
    val lastInboundSummary: String? = null,
    val lastLanError: String? = null,
    val lastRegister: String = "",
    val lastEnvelopePost: String = "",
    val lastCloudError: String = "",
    val interruptionFilterName: String = "",
    val ruleActive: Boolean = false,
    val vetoedOff: Boolean = false,
    val lastRemoteCommand: String? = null,
)
