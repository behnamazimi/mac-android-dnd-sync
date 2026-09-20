package com.dndsync.android.dnd

import android.app.NotificationManager
import android.content.Context
import android.content.SharedPreferences
import com.dndsync.android.pair.PairPrefs
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DndModule {
    @Provides
    @Singleton
    fun notificationManager(
        @ApplicationContext context: Context,
    ): NotificationManager = context.getSystemService(NotificationManager::class.java)

    @Provides
    @Singleton
    fun zenRulePrefs(
        @ApplicationContext context: Context,
    ): SharedPreferences = context.getSharedPreferences(ZenRuleIds.PREFS_NAME, Context.MODE_PRIVATE)

    @Provides
    @Singleton
    @PairPrefs
    fun pairPrefs(
        @ApplicationContext context: Context,
    ): SharedPreferences {
        val pair = context.getSharedPreferences(PAIR_PREFS_NAME, Context.MODE_PRIVATE)
        if (pair.getString(PAIR_BLOB, null) == null) {
            val zen = context.getSharedPreferences(ZenRuleIds.PREFS_NAME, Context.MODE_PRIVATE)
            val blob = zen.getString(PAIR_BLOB, null)
            val iv = zen.getString(PAIR_IV, null)
            if (blob != null && iv != null) {
                pair.edit().putString(PAIR_BLOB, blob).putString(PAIR_IV, iv).apply()
                zen.edit().remove(PAIR_BLOB).remove(PAIR_IV).apply()
            }
        }
        return pair
    }

    @Provides
    @Singleton
    @OnboardingPrefs
    fun onboardingPrefs(
        @ApplicationContext context: Context,
    ): SharedPreferences = context.getSharedPreferences("onboarding_prefs", Context.MODE_PRIVATE)

    private const val PAIR_PREFS_NAME = "pair"
    private const val PAIR_BLOB = "pair_blob"
    private const val PAIR_IV = "pair_iv"
}
