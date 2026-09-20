package com.dndsync.android

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.content.ContextCompat
import com.dndsync.android.dnd.DndApply
import com.dndsync.android.pair.PairSession
import com.dndsync.android.ui.navigation.AndroidRouting
import com.dndsync.android.ui.navigation.DndSyncNavHost
import com.dndsync.android.ui.navigation.OnboardingProgress
import com.dndsync.android.ui.onboarding.OnboardingPrefsStore
import com.dndsync.android.ui.theme.DndSyncTheme
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    @Inject lateinit var pairSession: PairSession
    @Inject lateinit var dndApply: DndApply
    @Inject lateinit var onboardingPrefs: OnboardingPrefsStore

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.auto(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.auto(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT),
        )
        val progress = OnboardingProgress(
            hasStoredPair = pairSession.hasStoredPair,
            joined = pairSession.joined,
            policyAccessGranted = dndApply.snapshot.value.policyAccessGranted,
            notificationsGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED,
            onboardingComplete = onboardingPrefs.isOnboardingComplete(),
        )
        val startDestination = AndroidRouting.route(AndroidRouting.destination(progress))
        setContent {
            DndSyncTheme {
                DndSyncNavHost(startDestination = startDestination)
            }
        }
    }
}
