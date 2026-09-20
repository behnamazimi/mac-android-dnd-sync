package com.dndsync.android.sync

import com.dndsync.proto.v1.DndState

class LanSyncGate(
    private val nowMs: () -> Long = { System.currentTimeMillis() },
) {
    var onOriginate: ((DndState) -> Unit)? = null
    var onApplyRemote: ((Boolean) -> Unit)? = null

    private val lock = Any()
    private var lastAppliedUnixMs: Long = 0
    private var lastAppliedOn: Boolean? = null
    private var applyingRemote = false
    private var echoUntilMs: Long = 0

    fun noteObserverEvent() {
        synchronized(lock) {
            applyingRemote = false
        }
    }

    fun reset() {
        synchronized(lock) {
            lastAppliedUnixMs = 0
            lastAppliedOn = null
            applyingRemote = false
            echoUntilMs = 0
        }
    }

    fun onLocalChange(on: Boolean) {
        val msg = synchronized(lock) {
            val now = nowMs()
            if (now >= echoUntilMs) {
                applyingRemote = false
            }
            if (applyingRemote || now < echoUntilMs) {
                return
            }
            // Applying a remote on/off can take longer than the 1s echo
            // window (Mac Shortcuts especially). The observer that then
            // fires is that apply, not a new user action.
            if (lastAppliedOn == on) {
                return
            }
            lastAppliedUnixMs = now
            lastAppliedOn = on
            DndState.newBuilder()
                .setVersion(Wire.PROTO_VERSION)
                .setOn(on)
                .setUnixMs(now)
                .setSender(Wire.SENDER_ANDROID)
                .build()
        }
        onOriginate?.invoke(msg)
    }

    fun onRemote(msg: DndState): Boolean {
        if (msg.version != Wire.PROTO_VERSION) {
            return false
        }
        val on = synchronized(lock) {
            if (msg.unixMs <= lastAppliedUnixMs) {
                return false
            }
            lastAppliedUnixMs = msg.unixMs
            lastAppliedOn = msg.on
            applyingRemote = true
            echoUntilMs = nowMs() + Wire.ECHO_WINDOW_MS
            msg.on
        }
        onApplyRemote?.invoke(on)
        return true
    }
}
