package com.dndsync.android.dnd

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.dndsync.android.R
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FailedOffNotifier @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    @SuppressLint("MissingPermission")
    fun notifyFailedOff() {
        if (ContextCompat.checkSelfPermission(
                context,
                android.Manifest.permission.POST_NOTIFICATIONS,
            ) != android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(context.getString(R.string.failed_off_title))
            .setContentText(context.getString(R.string.failed_off_body))
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(context.getString(R.string.failed_off_body)),
            )
            .setContentIntent(modesSettingsPendingIntent())
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()

        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
    }

    fun cancelFailedOff() {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    private fun modesSettingsPendingIntent(): PendingIntent {
        val intent = modesSettingsIntent(context).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    companion object {
        const val CHANNEL_ID = "failed_off"
        const val NOTIFICATION_ID = 1

        fun ensureChannel(context: Context, notificationManager: NotificationManager) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.failed_off_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            )
            channel.description = context.getString(R.string.failed_off_channel_description)
            notificationManager.createNotificationChannel(channel)
        }

        fun modesSettingsIntent(context: Context): Intent {
            val zenMode = Intent(ACTION_ZEN_MODE_SETTINGS)
            if (zenMode.resolveActivity(context.packageManager) != null) {
                return zenMode
            }
            return Intent(Settings.ACTION_CONDITION_PROVIDER_SETTINGS)
        }

        private const val ACTION_ZEN_MODE_SETTINGS = "android.settings.ZEN_MODE_SETTINGS"
    }
}
