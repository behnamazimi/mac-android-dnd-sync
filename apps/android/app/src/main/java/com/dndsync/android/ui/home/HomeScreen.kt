package com.dndsync.android.ui.home

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.dndsync.android.R
import com.dndsync.android.dnd.DndAccessSettings
import com.dndsync.android.dnd.FailedOffNotifier
import com.dndsync.android.ui.copy.HomeCopy
import com.dndsync.android.ui.copy.ProductCopy
import com.dndsync.android.ui.designsystem.BrandHeader
import com.dndsync.android.ui.designsystem.ConnectionPath
import com.dndsync.android.ui.designsystem.ConnectionPathChip
import com.dndsync.android.ui.designsystem.PillTone
import com.dndsync.android.ui.designsystem.RecentActivityList
import com.dndsync.android.ui.designsystem.ScreenScaffold
import com.dndsync.android.ui.designsystem.StatusCard
import com.dndsync.android.ui.designsystem.StatusIconCircle

@Composable
fun HomeScreen(
    onSettings: () -> Unit,
    viewModel: HomeViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current

    ScreenScaffold {
        BrandHeader(title = ProductCopy.APP_NAME, onSettings = onSettings)

        val presentation = presentationFor(state.status, state.dndOn, state.peerDeviceName)
        StatusCard(
            leading = {
                StatusIconCircle(tone = presentation.tone, iconRes = presentation.iconRes)
            },
            tone = presentation.tone,
            headline = presentation.headline,
            subline = presentation.subline,
            modifier = Modifier.fillMaxWidth(),
            trailingChip = { ConnectionPathChip(path = state.connectionPath) },
            ctaLabel = presentation.ctaLabel,
            onCta = presentation.ctaAction?.let { action ->
                {
                    when (action) {
                        CtaAction.OpenFocusAccessSettings ->
                            context.startActivity(DndAccessSettings.intent(context.packageName))
                        CtaAction.OpenModesSettings ->
                            context.startActivity(FailedOffNotifier.modesSettingsIntent(context))
                        CtaAction.OpenAppSettings -> onSettings()
                    }
                }
            },
        )

        RecentActivityList(items = state.recentActivity, modifier = Modifier.fillMaxWidth())
    }
}

@Preview(showBackground = true)
@Preview(showBackground = true, uiMode = android.content.res.Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun HomeScreenPreview() {
    com.dndsync.android.ui.theme.DndSyncTheme {
        ScreenScaffold {
            BrandHeader(title = ProductCopy.APP_NAME, onSettings = {})
            StatusCard(
                leading = {
                    StatusIconCircle(tone = PillTone.Ok, iconRes = R.drawable.ic_check_circle)
                },
                tone = PillTone.Ok,
                headline = HomeCopy.DND_OFF_HEADLINE,
                subline = HomeCopy.syncedWith("Mac"),
                modifier = Modifier.fillMaxWidth(),
                trailingChip = { ConnectionPathChip(path = ConnectionPath.Lan) },
            )
        }
    }
}

private enum class CtaAction { OpenFocusAccessSettings, OpenModesSettings, OpenAppSettings }

private data class StatusPresentation(
    val tone: PillTone,
    val iconRes: Int?,
    val headline: String,
    val subline: String,
    val ctaLabel: String? = null,
    val ctaAction: CtaAction? = null,
)

private fun presentationFor(status: HomeStatus, dndOn: Boolean, peerDeviceName: String): StatusPresentation = when (status) {
    HomeStatus.Synced -> StatusPresentation(
        tone = PillTone.Ok,
        iconRes = R.drawable.ic_check_circle,
        headline = if (dndOn) HomeCopy.DND_ON_HEADLINE else HomeCopy.DND_OFF_HEADLINE,
        subline = HomeCopy.syncedWith(peerDeviceName),
    )
    HomeStatus.Syncing -> StatusPresentation(
        tone = PillTone.Sync,
        iconRes = null,
        headline = HomeCopy.SYNCING_HEADLINE,
        subline = HomeCopy.SYNCING_SUBLINE,
    )
    is HomeStatus.NeedsAttention -> when (status.reason) {
        AttentionReason.FocusAccessRevoked -> StatusPresentation(
            tone = PillTone.Warn,
            iconRes = R.drawable.ic_warning,
            headline = HomeCopy.NEEDS_ATTENTION_HEADLINE,
            subline = HomeCopy.FOCUS_ACCESS_REVOKED_SUBLINE,
            ctaLabel = ProductCopy.FOCUS_ACCESS_PRIMARY,
            ctaAction = CtaAction.OpenFocusAccessSettings,
        )
        AttentionReason.NoNetwork -> StatusPresentation(
            tone = PillTone.Warn,
            iconRes = R.drawable.ic_cloud,
            headline = HomeCopy.NO_NETWORK_HEADLINE,
            subline = HomeCopy.NO_NETWORK_SUBLINE,
        )
        AttentionReason.PairingExpired -> StatusPresentation(
            tone = PillTone.Warn,
            iconRes = R.drawable.ic_warning,
            headline = HomeCopy.PAIRING_EXPIRED_HEADLINE,
            subline = HomeCopy.PAIRING_EXPIRED_SUBLINE,
            ctaLabel = HomeCopy.OPEN_SETTINGS,
            ctaAction = CtaAction.OpenAppSettings,
        )
        AttentionReason.ApplyDropped -> StatusPresentation(
            tone = PillTone.Warn,
            iconRes = R.drawable.ic_warning,
            headline = HomeCopy.APPLY_DROPPED_HEADLINE,
            subline = HomeCopy.APPLY_DROPPED_SUBLINE,
            ctaLabel = ProductCopy.FOCUS_ACCESS_PRIMARY,
            ctaAction = CtaAction.OpenFocusAccessSettings,
        )
    }
    HomeStatus.OffDidntApply -> StatusPresentation(
        tone = PillTone.Err,
        iconRes = R.drawable.ic_warning,
        headline = HomeCopy.OFF_DIDNT_APPLY_HEADLINE,
        subline = HomeCopy.OFF_DIDNT_APPLY_SUBLINE,
        ctaLabel = HomeCopy.OPEN_FOCUS_SETTINGS,
        ctaAction = CtaAction.OpenModesSettings,
    )
}
