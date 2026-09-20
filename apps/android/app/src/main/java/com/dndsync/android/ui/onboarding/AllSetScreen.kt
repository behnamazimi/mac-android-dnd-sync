package com.dndsync.android.ui.onboarding

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.dndsync.android.R
import com.dndsync.android.ui.copy.ProductCopy
import com.dndsync.android.ui.designsystem.ConnectionPathChip
import com.dndsync.android.ui.designsystem.MetaText
import com.dndsync.android.ui.designsystem.PillTone
import com.dndsync.android.ui.designsystem.PrimaryButton
import com.dndsync.android.ui.designsystem.ScreenScaffold
import com.dndsync.android.ui.designsystem.ScreenTitle
import com.dndsync.android.ui.designsystem.SectionGroup
import com.dndsync.android.ui.designsystem.StatusIconCircle
import com.dndsync.android.ui.navigation.Routes
import java.util.concurrent.atomic.AtomicBoolean

/** The tangible reward for finishing setup — Done is the last impression. */
@Composable
fun AllSetScreen(
    navController: NavController,
    viewModel: OnboardingViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val finished = remember { AtomicBoolean(false) }
    val goHome: () -> Unit = {
        if (finished.compareAndSet(false, true)) {
            viewModel.markOnboardingComplete()
            navController.navigate(Routes.Home) { popUpTo(Routes.Welcome) { inclusive = true } }
        }
    }

    ScreenScaffold(
        hero = true,
        bottomBar = {
            PrimaryButton(label = ProductCopy.ALL_SET_CONTINUE, onClick = goHome)
        },
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            StatusIconCircle(tone = PillTone.Ok, iconRes = R.drawable.ic_check_circle, size = 64.dp)
            Spacer(modifier = Modifier.height(24.dp))
            SectionGroup(horizontalAlignment = Alignment.CenterHorizontally) {
                ScreenTitle(
                    text = ProductCopy.ALL_SET_TITLE,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
                MetaText(
                    text = state.peerDeviceName,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
                ConnectionPathChip(path = state.connectionPath)
            }
        }
    }
}
