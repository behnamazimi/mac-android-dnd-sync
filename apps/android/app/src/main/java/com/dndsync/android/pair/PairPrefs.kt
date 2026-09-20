package com.dndsync.android.pair

import javax.inject.Qualifier

/** Hilt qualifier for the encrypted pair-blob SharedPreferences. */
@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class PairPrefs
