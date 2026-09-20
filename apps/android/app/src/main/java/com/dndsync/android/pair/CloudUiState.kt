package com.dndsync.android.pair

data class CloudUiState(
    val forwarderUrl: String = "—",
    val lastRegister: String = "—",
    val lastEnvelopePost: String = "—",
    val lastCloudError: String = "—",
    val pairStatus: String = "not paired",
    val pairId: String = "",
    val joinSucceeded: Boolean = false,
    val waitingForFcm: Boolean = false,
    val pairingExpired: Boolean = false,
    val pairError: String? = null,
    val macDeviceName: String = "",
    val lastSyncUnixMs: Long = 0L,
    val lastSyncOn: Boolean = false,
    val lastSyncSender: String = "",
    val lastSyncViaLan: Boolean = false,
)
