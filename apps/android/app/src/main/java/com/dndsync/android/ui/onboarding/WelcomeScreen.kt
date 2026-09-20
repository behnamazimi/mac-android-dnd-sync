package com.dndsync.android.ui.onboarding

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.dndsync.android.ui.copy.ProductCopy
import com.dndsync.android.ui.designsystem.BodyText
import com.dndsync.android.ui.designsystem.BrandMark
import com.dndsync.android.ui.designsystem.DisplayTitle
import com.dndsync.android.ui.designsystem.PrimaryButton
import com.dndsync.android.ui.designsystem.ScreenScaffold
import com.dndsync.android.ui.designsystem.SectionGroup
import com.dndsync.android.ui.theme.DndSyncTheme

/** First onboarding screen: states the value prop before anything is requested. */
@Composable
fun WelcomeScreen(onContinue: () -> Unit) {
    ScreenScaffold(
        hero = true,
        bottomBar = {
            PrimaryButton(label = ProductCopy.WELCOME_PRIMARY, onClick = onContinue)
        },
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            BrandMark(size = 72.dp)
            Spacer(modifier = Modifier.height(24.dp))
            SectionGroup(horizontalAlignment = Alignment.CenterHorizontally) {
                DisplayTitle(
                    text = ProductCopy.WELCOME_TITLE,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
                BodyText(
                    text = ProductCopy.WELCOME_BODY,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

@Preview(showBackground = true)
@Preview(showBackground = true, uiMode = android.content.res.Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun WelcomeScreenPreview() {
    DndSyncTheme {
        WelcomeScreen(onContinue = {})
    }
}
