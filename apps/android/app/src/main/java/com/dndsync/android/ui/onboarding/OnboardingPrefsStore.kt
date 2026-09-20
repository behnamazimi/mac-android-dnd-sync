package com.dndsync.android.ui.onboarding

import android.content.SharedPreferences
import com.dndsync.android.dnd.OnboardingPrefs
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Tracks whether a runtime permission was ever requested before, so a first
 * camera denial can be told apart from a later one. Navigation-compose's
 * back stack decides which screen shows.
 */
@Singleton
class OnboardingPrefsStore @Inject constructor(
    @OnboardingPrefs private val prefs: SharedPreferences,
) {
    enum class TrackedPermission(val prefKey: String) {
        Notifications("asked_notifications"),
        Camera("asked_camera"),
    }

    fun wasEverRequested(permission: TrackedPermission): Boolean =
        prefs.getBoolean(permission.prefKey, false)

    fun markRequested(permission: TrackedPermission) {
        prefs.edit().putBoolean(permission.prefKey, true).apply()
    }

    fun isOnboardingComplete(): Boolean =
        prefs.getBoolean(PREF_ONBOARDING_COMPLETE, false)

    fun markOnboardingComplete() {
        prefs.edit().putBoolean(PREF_ONBOARDING_COMPLETE, true).apply()
    }

    fun clearOnboardingComplete() {
        prefs.edit().remove(PREF_ONBOARDING_COMPLETE).apply()
    }

    private companion object {
        const val PREF_ONBOARDING_COMPLETE = "onboarding_complete"
    }
}
