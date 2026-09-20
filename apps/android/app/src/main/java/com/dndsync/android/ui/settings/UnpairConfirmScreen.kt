package com.dndsync.android.ui.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.dndsync.android.R
import com.dndsync.android.ui.copy.ProductCopy
import com.dndsync.android.ui.designsystem.BodyText
import com.dndsync.android.ui.designsystem.InGroup
import com.dndsync.android.ui.designsystem.OutlineButton
import com.dndsync.android.ui.designsystem.PillTone
import com.dndsync.android.ui.designsystem.QuietButton
import com.dndsync.android.ui.designsystem.ScreenHeader
import com.dndsync.android.ui.designsystem.ScreenScaffold
import com.dndsync.android.ui.designsystem.ScreenTitle
import com.dndsync.android.ui.designsystem.SectionGroup
import com.dndsync.android.ui.designsystem.StatusIconCircle
import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.flowWithLifecycle

/** The one truly destructive action in the app gets the one truly destructive button. */
@Composable
fun UnpairConfirmScreen(
    onBack: () -> Unit,
    onUnpaired: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel(),
) {
    val lifecycleOwner = LocalLifecycleOwner.current
    LaunchedEffect(viewModel, lifecycleOwner) {
        viewModel.eventFlow.flowWithLifecycle(lifecycleOwner.lifecycle, Lifecycle.State.STARTED)
            .collect { event ->
                if (event is SettingsEvent.Unpaired) {
                    onUnpaired()
                }
            }
    }

    ScreenScaffold(
        hero = true,
        topBar = { ScreenHeader(title = ProductCopy.UNPAIR_CONFIRM_TITLE, onBack = onBack) },
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(InGroup),
            modifier = Modifier.fillMaxWidth(),
        ) {
            StatusIconCircle(tone = PillTone.Err, iconRes = R.drawable.ic_warning, size = 56.dp)
            ScreenTitle(
                text = ProductCopy.UNPAIR_CONFIRM_HEADLINE,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            BodyText(
                text = ProductCopy.UNPAIR_CONFIRM_BODY,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        SectionGroup {
            OutlineButton(
                label = ProductCopy.UNPAIR,
                destructive = true,
                onClick = { viewModel.unpair() },
            )
            QuietButton(label = ProductCopy.CANCEL, onClick = onBack)
        }
    }
}
