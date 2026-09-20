package com.dndsync.android.lan

data class LanUiState(
    val advertising: Boolean = false,
    val browsing: Boolean = false,
    val connected: Boolean = false,
    val lastInboundSummary: String? = null,
    val lastError: String? = null,
)
