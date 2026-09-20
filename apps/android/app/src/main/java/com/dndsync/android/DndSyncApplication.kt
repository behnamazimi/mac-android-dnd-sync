package com.dndsync.android

import android.Manifest
import android.app.Application
import android.app.NotificationManager
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.dndsync.android.dnd.FailedOffNotifier
import com.dndsync.android.dnd.FcmTokenBootstrapper
import com.dndsync.android.sync.SyncSession
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class DndSyncApplication : Application() {
    @Inject
    lateinit var syncSession: SyncSession

    @Inject
    lateinit var fcmTokenBootstrapper: FcmTokenBootstrapper

    override fun onCreate() {
        super.onCreate()
        FailedOffNotifier.ensureChannel(
            this,
            getSystemService(NotificationManager::class.java),
        )
        syncSession.setNearbyGranted(
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.NEARBY_WIFI_DEVICES,
            ) == PackageManager.PERMISSION_GRANTED,
        )
        fcmTokenBootstrapper.start()
    }
}
