package com.dndsync.android.sync

/** Wire meaning shared by LAN frames, CloudEnvelope, and FCM data keys. */
object Wire {
    const val PROTO_VERSION = 1
    const val PAIR_CONTROL_VERSION = 2
    const val SENDER_MAC = "mac"
    const val SENDER_ANDROID = "android"
    const val ECHO_WINDOW_MS = 1_000L
    const val PAYLOAD_DND_STATE = 0
    const val PAYLOAD_PAIR_CONTROL = 1
    const val FCM_ENVELOPE_B64 = "envelope_b64"
    const val FCM_COMMAND = "command"
    const val FCM_COMMAND_ON = "on"
    const val FCM_COMMAND_OFF = "off"
    const val HKDF_INFO = "dndsync-e2e-v1"
    const val PLATFORM_FCM = "fcm"
}
