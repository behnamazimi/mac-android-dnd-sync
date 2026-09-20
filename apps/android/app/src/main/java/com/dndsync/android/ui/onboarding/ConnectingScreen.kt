package com.dndsync.android.ui.onboarding

import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.dndsync.android.ui.copy.ProductCopy
import com.dndsync.android.ui.designsystem.BodyText
import com.dndsync.android.ui.designsystem.ErrorText
import com.dndsync.android.ui.designsystem.MetaText
import com.dndsync.android.ui.designsystem.OutlineButton
import com.dndsync.android.ui.designsystem.ScreenHeader
import com.dndsync.android.ui.designsystem.ScreenScaffold
import com.dndsync.android.ui.designsystem.SectionGroup
import com.dndsync.android.ui.navigation.Origin
import com.dndsync.android.ui.navigation.Routes

/**
 * Waits for the pairing handshake. On success, routes onward differently by [origin]:
 * a first-run pairing continues into the permission-priming steps (skipping any
 * already granted), a re-pair goes straight back to Home — Principle D, recover in
 * place, never replay onboarding for a returning user.
 */
@Composable
fun ConnectingScreen(
    origin: Origin,
    navController: NavController,
    onBack: () -> Unit,
    viewModel: OnboardingViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    LaunchedEffect(state.joinSucceeded, origin) {
        if (!state.joinSucceeded) return@LaunchedEffect
        if (origin == Origin.Repair) {
            navController.navigate(Routes.Home) {
                popUpTo(Routes.Home) { inclusive = true }
            }
            return@LaunchedEffect
        }
        val next = when {
            !state.policyAccessGranted -> Routes.FocusAccess
            !state.notificationsGranted -> Routes.NotificationsAccess
            else -> Routes.AllSet
        }
        navController.navigate(next)
    }

    ScreenScaffold {
        ScreenHeader(title = ProductCopy.CONNECTING_TITLE, onBack = onBack)
        SectionGroup {
            CircularProgressIndicator(
                modifier = Modifier.size(40.dp),
                color = MaterialTheme.colorScheme.secondary,
            )
            BodyText(ProductCopy.CONNECTING_BODY)
            if (state.pairError == null) {
                MetaText(ProductCopy.CONNECTING_NETWORK_TITLE)
                MetaText(ProductCopy.CONNECTING_NETWORK_BODY)
            }
            if (state.waitingForFcm) {
                MetaText(ProductCopy.CONNECTING_WAITING_FCM)
            }
            if (state.pairError != null) {
                ErrorText(state.pairError)
                OutlineButton(label = ProductCopy.CONNECTING_RETRY, onClick = onBack)
            }
        }
    }
}
