package com.dndsync.android.dnd

import android.net.Uri

internal object ZenRuleIds {
    const val PREFS_NAME = "zen_rule"
    const val PREF_RULE_ID = "rule_id"
    const val PREF_RULE_ACTIVE = "rule_active"
    const val PREF_RULE_REBUILT = "rule_rebuilt_v2"
    const val PREF_FCM_TOKEN = "fcm_token"
    val CONDITION_ID: Uri = Uri.parse("dndsync://zen")
}
