package com.dndsync.android.ui.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dndsync.android.R
import com.dndsync.android.ui.copy.ProductCopy
import com.dndsync.android.ui.designsystem.BodyText
import com.dndsync.android.ui.designsystem.InGroup
import com.dndsync.android.ui.designsystem.PillTone
import com.dndsync.android.ui.designsystem.PrimaryButton
import com.dndsync.android.ui.designsystem.QuietButton
import com.dndsync.android.ui.designsystem.ScreenHeader
import com.dndsync.android.ui.designsystem.ScreenScaffold
import com.dndsync.android.ui.designsystem.ScreenTitle
import com.dndsync.android.ui.designsystem.SectionGroup
import com.dndsync.android.ui.designsystem.StatusIconCircle

/** Confirms before disconnecting the current Mac — a plain tap shouldn't do that. */
@Composable
fun RepairConfirmScreen(
    onBack: () -> Unit,
    onStartNewPairing: () -> Unit,
) {
    ScreenScaffold(
        hero = true,
        topBar = { ScreenHeader(title = ProductCopy.REPAIR_CONFIRM_TITLE, onBack = onBack) },
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(InGroup),
            modifier = Modifier.fillMaxWidth(),
        ) {
            StatusIconCircle(tone = PillTone.Warn, iconRes = R.drawable.ic_warning, size = 56.dp)
            ScreenTitle(
                text = ProductCopy.REPAIR_CONFIRM_HEADLINE,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            BodyText(
                text = ProductCopy.REPAIR_CONFIRM_BODY,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        SectionGroup {
            PrimaryButton(label = ProductCopy.START_NEW_PAIRING, onClick = onStartNewPairing)
            QuietButton(label = ProductCopy.CANCEL, onClick = onBack)
        }
    }
}
