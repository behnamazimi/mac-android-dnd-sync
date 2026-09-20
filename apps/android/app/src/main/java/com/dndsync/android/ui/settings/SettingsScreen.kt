package com.dndsync.android.ui.settings

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.HorizontalDivider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.dndsync.android.ui.copy.ProductCopy
import com.dndsync.android.ui.designsystem.Card
import com.dndsync.android.ui.designsystem.MetaText
import com.dndsync.android.ui.designsystem.PillTone
import com.dndsync.android.ui.designsystem.ScreenHeader
import com.dndsync.android.ui.designsystem.ScreenScaffold
import com.dndsync.android.ui.designsystem.SectionGroup
import com.dndsync.android.ui.designsystem.SettingsInfoRow
import com.dndsync.android.ui.designsystem.SettingsRow
import com.dndsync.android.ui.designsystem.SettingsSwitchRow
import com.dndsync.android.ui.designsystem.StatusPill

@Composable
fun SettingsScreen(
    onBack: () -> Unit,
    onRepair: () -> Unit,
    onUnpair: () -> Unit,
    onAbout: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current

    val nearbyLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted -> viewModel.onNearbyPermissionResult(granted) }
    val notificationsLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted -> viewModel.onNotificationsPermissionResult(granted) }

    LifecycleResumeEffect(Unit) {
        viewModel.refreshPermissions()
        onPauseOrDispose { }
    }

    val appDetails = { context.startActivity(appDetailsIntent(context.packageName)) }

    ScreenScaffold {
        ScreenHeader(title = ProductCopy.SETTINGS_TITLE, onBack = onBack)

        SectionGroup {
            MetaText(ProductCopy.PAIRED_DEVICE_SECTION)
            Card {
                SettingsInfoRow(label = state.peerDeviceName) {
                    StatusPill(
                        label = if (state.connected) ProductCopy.CONNECTED else ProductCopy.NOT_CONNECTED,
                        tone = if (state.connected) PillTone.Ok else PillTone.Neutral,
                    )
                }
                HorizontalDivider()
                SettingsRow(label = ProductCopy.REPAIR, onClick = onRepair)
                SettingsRow(label = ProductCopy.UNPAIR, onClick = onUnpair, destructive = true)
            }
        }

        SectionGroup {
            MetaText(ProductCopy.SYNC_SECTION)
            Card {
                SettingsSwitchRow(
                    label = ProductCopy.NEARBY_DEVICES,
                    checked = state.nearbyGranted,
                    onCheckedChange = { wantOn ->
                        when {
                            wantOn && !state.nearbyGranted ->
                                nearbyLauncher.launch(Manifest.permission.NEARBY_WIFI_DEVICES)
                            !wantOn && state.nearbyGranted -> appDetails()
                        }
                    },
                )
                SettingsSwitchRow(
                    label = ProductCopy.NOTIFY_ON_FAILURE,
                    checked = state.notificationsGranted,
                    onCheckedChange = { wantOn ->
                        when {
                            wantOn && !state.notificationsGranted ->
                                notificationsLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                            !wantOn && state.notificationsGranted -> appDetails()
                        }
                    },
                )
            }
        }

        SectionGroup {
            MetaText(ProductCopy.ABOUT_SECTION)
            Card {
                SettingsRow(label = ProductCopy.ABOUT_TITLE, onClick = onAbout)
            }
        }
    }
}

private fun appDetailsIntent(packageName: String): Intent =
    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
        data = Uri.fromParts("package", packageName, null)
    }

@Preview(showBackground = true)
@Preview(showBackground = true, uiMode = android.content.res.Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun SettingsScreenPreview() {
    com.dndsync.android.ui.theme.DndSyncTheme {
        ScreenScaffold {
            ScreenHeader(title = ProductCopy.SETTINGS_TITLE, onBack = {})
            SectionGroup {
                MetaText(ProductCopy.PAIRED_DEVICE_SECTION)
                Card {
                    SettingsInfoRow(label = "Mac") {
                        StatusPill(label = ProductCopy.CONNECTED, tone = PillTone.Ok)
                    }
                }
            }
            SectionGroup {
                MetaText(ProductCopy.SYNC_SECTION)
                Card {
                    SettingsSwitchRow(
                        label = ProductCopy.NOTIFY_ON_FAILURE,
                        checked = true,
                        onCheckedChange = {},
                    )
                }
            }
        }
    }
}
