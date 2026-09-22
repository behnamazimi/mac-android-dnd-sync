package com.dndsync.android.ui.home

import android.text.format.DateUtils
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dndsync.android.dnd.DndApply
import com.dndsync.android.dnd.DndApplyPolicy
import com.dndsync.android.dnd.DndApplySnapshot
import com.dndsync.android.lan.LanUiState
import com.dndsync.android.net.NetworkPathMonitor
import com.dndsync.android.pair.CloudUiState
import com.dndsync.android.pair.PairSession
import com.dndsync.android.sync.SyncSession
import com.dndsync.android.ui.designsystem.ActivityRow
import com.dndsync.android.ui.designsystem.ConnectionPath
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

private data class LanBits(val ui: LanUiState, val applyDropped: Boolean, val applyingRemote: Boolean)

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val dndApply: DndApply,
    private val syncSession: SyncSession,
    private val pairSession: PairSession,
    networkPathMonitor: NetworkPathMonitor,
) : ViewModel() {
    private val events = MutableStateFlow<List<SyncEvent>>(emptyList())

    init {
        val seed = pairSession.ui.value
        if (RecentActivity.hasSync(seed.lastSyncUnixMs)) {
            events.value = listOf(SyncEvent(seed.lastSyncUnixMs, seed.lastSyncOn, seed.lastSyncSender))
        }
        viewModelScope.launch {
            pairSession.ui
                .map { SyncEvent(it.lastSyncUnixMs, it.lastSyncOn, it.lastSyncSender) }
                .distinctUntilChanged()
                .collect { event ->
                    if (!RecentActivity.hasSync(event.unixMs)) return@collect
                    events.update { current ->
                        (listOf(event) + current.filterNot { it.unixMs == event.unixMs }).take(MAX_EVENTS)
                    }
                }
        }
    }

    val uiState: StateFlow<HomeUiState> = combine(
        dndApply.snapshot,
        combine(
            syncSession.lanUi,
            dndApply.applyDropped,
            dndApply.applyingRemote,
        ) { ui, dropped, applying -> LanBits(ui, dropped, applying) },
        pairSession.ui,
        networkPathMonitor.satisfied,
        events,
    ) { snap, lan, cloud, netSatisfied, evts ->
        toUiState(snap, lan, cloud, netSatisfied, evts)
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = HomeUiState(),
    )

    private fun toUiState(
        snap: DndApplySnapshot,
        lan: LanBits,
        cloud: CloudUiState,
        networkSatisfied: Boolean,
        evts: List<SyncEvent>,
    ): HomeUiState {
        val status = HomeStatusResolver.from(
            policyAccessGranted = snap.policyAccessGranted,
            networkSatisfied = networkSatisfied,
            pairingExpired = cloud.pairingExpired,
            applyDropped = lan.applyDropped,
            vetoedOff = snap.vetoedOff,
            applyingRemote = lan.applyingRemote,
        )
        return HomeUiState(
            status = status,
            dndOn = DndApplyPolicy.displayOn(snap.interruptionFilter),
            connectionPath = when {
                cloud.lastSyncViaLan -> ConnectionPath.Lan
                cloud.joinSucceeded -> ConnectionPath.Cloud
                else -> ConnectionPath.None
            },
            peerDeviceName = RecentActivity.peerLabel(cloud.macDeviceName),
            recentActivity = evts.map {
                ActivityRow(
                    timeLabel = relativeTime(it.unixMs),
                    line = RecentActivity.line(it.on, it.sender),
                )
            },
        )
    }

    private fun relativeTime(unixMs: Long): String =
        DateUtils.getRelativeTimeSpanString(unixMs, System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS).toString()

    private companion object {
        const val MAX_EVENTS = 5
    }
}
