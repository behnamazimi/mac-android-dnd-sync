package com.dndsync.android.dnd

import android.content.Intent
import android.os.Bundle
import android.provider.Settings

/**
 * Opens the system Do Not Disturb access list scrolled to this app.
 * There is no runtime Allow/Deny dialog for this grant — special-access
 * settings is the only official path.
 */
object DndAccessSettings {
    fun intent(packageName: String): Intent {
        val highlight = Bundle().apply {
            putString(FRAGMENT_ARG_KEY, packageName)
        }
        return Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            putExtra(FRAGMENT_ARG_KEY, packageName)
            putExtra(SHOW_FRAGMENT_ARGS, highlight)
        }
    }

    // AOSP Settings keys: PreferenceFragmentCompat scrolls to and highlights
    // the row whose key matches (here, the app's package name).
    const val FRAGMENT_ARG_KEY = ":settings:fragment_args_key"
    const val SHOW_FRAGMENT_ARGS = ":settings:show_fragment_args"
}
