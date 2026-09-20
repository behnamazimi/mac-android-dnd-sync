package com.dndsync.android.pair

import android.content.SharedPreferences
import com.dndsync.android.dnd.ZenRuleIds
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FcmTokenStore @Inject constructor(
    private val prefs: SharedPreferences,
) {
    private val _token = MutableStateFlow(prefs.getString(ZenRuleIds.PREF_FCM_TOKEN, null))
    val tokenFlow: StateFlow<String?> = _token.asStateFlow()
    val token: String? get() = _token.value

    fun set(token: String) {
        prefs.edit().putString(ZenRuleIds.PREF_FCM_TOKEN, token).apply()
        _token.value = token
    }
}
