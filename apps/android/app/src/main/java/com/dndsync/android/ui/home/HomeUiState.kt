package com.dndsync.android.ui.home

import com.dndsync.android.ui.designsystem.ActivityRow
import com.dndsync.android.ui.designsystem.ConnectionPath

data class HomeUiState(
    val status: HomeStatus = HomeStatus.Synced,
    val dndOn: Boolean = false,
    val connectionPath: ConnectionPath = ConnectionPath.None,
    val peerDeviceName: String = "",
    val recentActivity: List<ActivityRow> = emptyList(),
)
