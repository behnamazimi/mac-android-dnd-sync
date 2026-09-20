package com.dndsync.android.dnd

import javax.inject.Qualifier

/** Hilt qualifier for the `onboarding_prefs` SharedPreferences provided in [DndModule]. */
@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class OnboardingPrefs
