package com.dndsync.android.dnd

import android.app.AutomaticZenRule
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.service.notification.Condition
import com.dndsync.android.MainActivity
import com.dndsync.android.R
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ZenRuleController @Inject constructor(
    @ApplicationContext private val context: Context,
    private val notificationManager: NotificationManager,
    private val prefs: SharedPreferences,
) {
    fun isActive(): Boolean = prefs.getBoolean(ZenRuleIds.PREF_RULE_ACTIVE, false)

    fun ensureRule(): String? {
        rebuildOwnedRulesIfNeeded()

        val existingId = prefs.getString(ZenRuleIds.PREF_RULE_ID, null)
        if (existingId != null) {
            val existing = notificationManager.getAutomaticZenRule(existingId)
            if (existing != null) {
                ensureEnabled(existingId, existing)
                val displayName = context.getString(R.string.zen_rule_name)
                if (existing.name != displayName) {
                    existing.name = displayName
                    try {
                        notificationManager.updateAutomaticZenRule(existingId, existing)
                    } catch (_: SecurityException) {
                    }
                }
                return existingId
            }
        }

        return addRule()
    }

    fun setActive(active: Boolean): Boolean {
        val id = ensureRule() ?: return false
        val rule = notificationManager.getAutomaticZenRule(id)
        if (rule != null) {
            ensureEnabled(id, rule)
        }
        val state = if (active) Condition.STATE_TRUE else Condition.STATE_FALSE
        return try {
            notificationManager.setAutomaticZenRuleState(
                id,
                Condition(
                    ZenRuleIds.CONDITION_ID,
                    context.getString(R.string.zen_rule_name),
                    state,
                    Condition.SOURCE_USER_ACTION,
                ),
            )
            prefs.edit().putBoolean(ZenRuleIds.PREF_RULE_ACTIVE, active).apply()
            true
        } catch (_: SecurityException) {
            false
        }
    }

    /**
     * Earlier apply-path experiments left extra or snoozed Modes. Drop them
     * once so the next toggle uses a single fresh rule, the same way the
     * original harness did.
     */
    private fun rebuildOwnedRulesIfNeeded() {
        if (prefs.getBoolean(ZenRuleIds.PREF_RULE_REBUILT, false)) {
            return
        }
        removeOwnedRules()
        prefs.edit()
            .remove(ZenRuleIds.PREF_RULE_ID)
            .putBoolean(ZenRuleIds.PREF_RULE_ACTIVE, false)
            .putBoolean(ZenRuleIds.PREF_RULE_REBUILT, true)
            .apply()
    }

    private fun addRule(): String? = try {
        val rule = AutomaticZenRule.Builder(
            context.getString(R.string.zen_rule_name),
            ZenRuleIds.CONDITION_ID,
        )
            .setType(AutomaticZenRule.TYPE_OTHER)
            .setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            .setEnabled(true)
            .setConfigurationActivity(ComponentName(context, MainActivity::class.java))
            .build()

        val id = notificationManager.addAutomaticZenRule(rule) ?: return null
        prefs.edit()
            .putString(ZenRuleIds.PREF_RULE_ID, id)
            .putBoolean(ZenRuleIds.PREF_RULE_ACTIVE, false)
            .apply()
        id
    } catch (_: SecurityException) {
        null
    }

    private fun ensureEnabled(id: String, rule: AutomaticZenRule) {
        if (rule.isEnabled) {
            return
        }
        rule.isEnabled = true
        try {
            notificationManager.updateAutomaticZenRule(id, rule)
        } catch (_: SecurityException) {
        }
    }

    private fun removeOwnedRules() {
        val owned = try {
            HashMap(notificationManager.automaticZenRules ?: emptyMap())
        } catch (_: SecurityException) {
            return
        }
        for (ruleId in owned.keys) {
            try {
                notificationManager.removeAutomaticZenRule(ruleId)
            } catch (_: SecurityException) {
            }
        }
        val stored = prefs.getString(ZenRuleIds.PREF_RULE_ID, null)
        if (stored != null && stored !in owned) {
            try {
                notificationManager.removeAutomaticZenRule(stored)
            } catch (_: SecurityException) {
            }
        }
    }
}
