package com.dndsync.android.dnd

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Observe system DND and apply a remote on/off. Callers never name the Zen rule.
 */
interface DndApply {
    val snapshot: StateFlow<DndApplySnapshot>
    val applyDropped: StateFlow<Boolean>
    val applyingRemote: StateFlow<Boolean>
    var onLocalChange: ((Boolean) -> Unit)?
    var onObserverEvent: (() -> Unit)?
    fun apply(on: Boolean)
    fun clearApplyDropped()
    fun recordRemoteCommand(command: String)
}

@Singleton
class ZenDndApply @Inject constructor(
    @ApplicationContext private val context: Context,
    private val zenRuleController: ZenRuleController,
    private val observer: DndSystemObserver,
    private val failedOffNotifier: FailedOffNotifier,
) : DndApply {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val veto = VetoIncidentTracker()
    private var pendingOff: Boolean = false
    private var offEvaluationJob: Job? = null
    private var applyingRemoteTimeoutJob: Job? = null

    override var onLocalChange: ((Boolean) -> Unit)? = null
    override var onObserverEvent: (() -> Unit)? = null

    private val _snapshot = MutableStateFlow(
        DndApplySnapshot(
            policyAccessGranted = observer.isPolicyAccessGranted(),
            interruptionFilter = observer.currentInterruptionFilter(),
            ruleActive = zenRuleController.isActive(),
            vetoedOff = false,
        ),
    )
    override val snapshot: StateFlow<DndApplySnapshot> = _snapshot.asStateFlow()

    private val _applyDropped = MutableStateFlow(false)
    override val applyDropped: StateFlow<Boolean> = _applyDropped.asStateFlow()

    private val _applyingRemote = MutableStateFlow(false)
    override val applyingRemote: StateFlow<Boolean> = _applyingRemote.asStateFlow()

    init {
        observer.interruptionFilter
            .onEach { filter -> onInterruptionFilter(filter) }
            .launchIn(scope)
        observer.interruptionFilterChanges
            .onEach { filter ->
                onObserverEvent?.invoke()
                _applyingRemote.value = false
                applyingRemoteTimeoutJob?.cancel()
                val on = DndApplyPolicy.binaryOn(filter) ?: return@onEach
                onLocalChange?.invoke(on)
            }
            .launchIn(scope)
        observer.policyAccessGranted
            .onEach { granted -> onPolicyAccess(granted) }
            .launchIn(scope)
    }

    override fun apply(on: Boolean) {
        _applyingRemote.value = true
        applyingRemoteTimeoutJob?.cancel()
        applyingRemoteTimeoutJob = scope.launch {
            delay(OffApplyPolicy.APPLYING_REMOTE_TIMEOUT_MS)
            _applyingRemote.value = false
        }
        if (!DndApplyPolicy.canApply(observer.isPolicyAccessGranted(), notificationsGranted())) {
            _applyDropped.value = true
            _applyingRemote.value = false
            applyingRemoteTimeoutJob?.cancel()
            return
        }
        _applyDropped.value = false
        setRuleActive(on)
    }

    override fun clearApplyDropped() {
        _applyDropped.value = false
    }

    override fun recordRemoteCommand(command: String) {
        _snapshot.update { it.copy(lastRemoteCommand = command) }
    }

    private fun setRuleActive(active: Boolean) {
        if (!observer.isPolicyAccessGranted()) {
            emitSnapshot()
            return
        }
        if (!zenRuleController.setActive(active)) {
            emitSnapshot()
            return
        }
        if (active) {
            pendingOff = false
            offEvaluationJob?.cancel()
            veto.onRuleTurnedOn()
            emitSnapshot()
            return
        }
        pendingOff = true
        val filter = observer.currentInterruptionFilter()
        if (OffApplyPolicy.filterIsAll(filter)) {
            settleOffSuccess(filter)
            return
        }
        emitSnapshot(interruptionFilter = filter)
        offEvaluationJob?.cancel()
        offEvaluationJob = scope.launch {
            delay(OffApplyPolicy.EVALUATION_DELAY_MS)
            evaluateOff()
        }
    }

    private fun onPolicyAccess(granted: Boolean) {
        if (granted) {
            zenRuleController.ensureRule()
        }
        emitSnapshot(policyAccessGranted = granted)
    }

    private fun onInterruptionFilter(filter: Int) {
        if (OffApplyPolicy.filterIsAll(filter)) {
            if (pendingOff || veto.vetoedOff) {
                settleOffSuccess(filter)
                return
            }
            pendingOff = false
            offEvaluationJob?.cancel()
            veto.onFilterAll()
        }
        // A non-ALL filter while pendingOff is the settle window, not a
        // veto. Android 15 Modes often broadcasts PRIORITY immediately
        // after setAutomaticZenRuleState(FALSE), before the global filter
        // actually drops.
        emitSnapshot(interruptionFilter = filter)
    }

    private fun evaluateOff() {
        if (!pendingOff) {
            emitSnapshot()
            return
        }
        val filter = observer.currentInterruptionFilter()
        if (OffApplyPolicy.filterIsAll(filter)) {
            settleOffSuccess(filter)
            return
        }
        if (OffApplyPolicy.shouldVetoAfterSettle(pendingOff, filter, settleElapsed = true)) {
            commitVeto()
        }
        emitSnapshot(interruptionFilter = filter)
    }

    private fun settleOffSuccess(filter: Int) {
        pendingOff = false
        offEvaluationJob?.cancel()
        applyingRemoteTimeoutJob?.cancel()
        _applyingRemote.value = false
        veto.onFilterAll()
        failedOffNotifier.cancelFailedOff()
        emitSnapshot(interruptionFilter = filter)
    }

    private fun commitVeto() {
        pendingOff = false
        offEvaluationJob?.cancel()
        applyingRemoteTimeoutJob?.cancel()
        _applyingRemote.value = false
        if (veto.onVetoedOff()) {
            failedOffNotifier.notifyFailedOff()
        }
    }

    private fun emitSnapshot(
        policyAccessGranted: Boolean = observer.isPolicyAccessGranted(),
        interruptionFilter: Int = observer.currentInterruptionFilter(),
    ) {
        _snapshot.update {
            DndApplySnapshot(
                policyAccessGranted = policyAccessGranted,
                interruptionFilter = interruptionFilter,
                ruleActive = zenRuleController.isActive(),
                vetoedOff = veto.vetoedOff,
                lastRemoteCommand = it.lastRemoteCommand,
            )
        }
    }

    private fun notificationsGranted(): Boolean =
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
}
