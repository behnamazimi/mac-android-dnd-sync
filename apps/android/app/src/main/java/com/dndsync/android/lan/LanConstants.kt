package com.dndsync.android.lan

/** Bonjour/NSD names and LAN frame limits. Wire version/senders live in [com.dndsync.android.sync.Wire]. */
object LanConstants {
    const val SERVICE_TYPE = "_dndsync._tcp."
    const val PAIR_ID = "dndsync-dev"
    const val PAIR_TXT_KEY = "pair"
    const val ANDROID_INSTANCE_NAME = "dndsync-dev-android"
    const val MAX_FRAME_BYTES = 64 * 1024
}
