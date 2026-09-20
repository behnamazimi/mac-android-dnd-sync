package com.dndsync.android.dnd

/**
 * Tracks one failed-off incident so the harness notifies at most once until
 * the user resolves DND or we turn our rule on again.
 */
class VetoIncidentTracker {
    var vetoedOff: Boolean = false
        private set

    private var incidentOpen: Boolean = false
    private var notifiedForIncident: Boolean = false

    fun onRuleTurnedOn() {
        clear()
    }

    fun onFilterAll() {
        clear()
    }

    /**
     * Records a vetoed off. Returns true when a notification must be fired
     * for this incident.
     */
    fun onVetoedOff(): Boolean {
        vetoedOff = true
        if (incidentOpen && notifiedForIncident) {
            return false
        }
        incidentOpen = true
        notifiedForIncident = true
        return true
    }

    private fun clear() {
        vetoedOff = false
        incidentOpen = false
        notifiedForIncident = false
    }
}
