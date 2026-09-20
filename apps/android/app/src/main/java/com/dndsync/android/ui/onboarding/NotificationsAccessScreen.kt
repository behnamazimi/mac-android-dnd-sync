package com.dndsync.android.ui.onboarding

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.dndsync.android.R
import com.dndsync.android.ui.copy.ProductCopy
import com.dndsync.android.ui.designsystem.PermissionPrimer
import com.dndsync.android.ui.designsystem.PillTone
import com.dndsync.android.ui.designsystem.ScreenHeader
import com.dndsync.android.ui.designsystem.ScreenScaffold
import com.dndsync.android.ui.navigation.Routes

/**
 * Scoped down to the one reason this permission is ever needed: telling you about a
 * failed Off. The system Allow/Deny sheet is the ask — Skip is the escape if they
 * don't want it.
 */
@Composable
fun NotificationsAccessScreen(
    navController: NavController,
    onBack: () -> Unit,
    viewModel: OnboardingViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    val launcher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted -> viewModel.onNotificationsPermissionResult(granted) }

    LaunchedEffect(state.notificationsGranted) {
        if (state.notificationsGranted) {
            navController.navigate(Routes.AllSet) { popUpTo(Routes.NotificationsAccess) { inclusive = true } }
        }
    }

    ScreenScaffold(
        hero = true,
        topBar = { ScreenHeader(title = ProductCopy.NOTIFICATIONS_HEADER, onBack = onBack) },
    ) {
        PermissionPrimer(
            iconRes = R.drawable.ic_bell,
            title = ProductCopy.NOTIFICATIONS_TITLE,
            body = ProductCopy.NOTIFICATIONS_BODY,
            primaryLabel = ProductCopy.NOTIFICATIONS_PRIMARY,
            tone = PillTone.Warn,
            secondaryLabel = ProductCopy.SKIP,
            onSecondary = { navController.navigate(Routes.AllSet) { popUpTo(Routes.NotificationsAccess) { inclusive = true } } },
            onPrimary = { launcher.launch(Manifest.permission.POST_NOTIFICATIONS) },
        )
    }
}
