package com.dndsync.android.pair

/**
 * Sentinel strings [PairSession] writes into [CloudUiState]. These are internal
 * markers, not display prose — the UI layer maps them to real copy.
 */
object CloudCopy {
    const val EM_DASH = "—"
    const val BAD_PAYLOAD = "That isn't a pairing code."
    const val JOIN_FAILED = "Couldn't connect. Check the internet and try again."
    const val PAIRING_EXPIRED = "Pairing expired. Connect again from Settings."
}
