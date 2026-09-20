package com.dndsync.android.ui.onboarding

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalContext
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.dndsync.android.R
import com.dndsync.android.dnd.DndAccessSettings
import com.dndsync.android.ui.copy.ProductCopy
import com.dndsync.android.ui.designsystem.PillTone
import com.dndsync.android.ui.designsystem.PermissionPrimer
import com.dndsync.android.ui.designsystem.ScreenHeader
import com.dndsync.android.ui.designsystem.ScreenScaffold
import com.dndsync.android.ui.navigation.Routes

/**
 * Explains the one permission sync actually needs, then opens the system
 * Do Not Disturb access list on this app. Auto-advances the moment access
 * is granted — [com.dndsync.android.dnd.DndSystemObserver] observes it via
 * a system broadcast, so no manual resume-poll is needed here.
 */
@Composable
fun FocusAccessScreen(
    navController: NavController,
    onBack: () -> Unit,
    viewModel: OnboardingViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current

    LaunchedEffect(state.policyAccessGranted) {
        if (state.policyAccessGranted) {
            val next = if (!state.notificationsGranted) {
                Routes.NotificationsAccess
            } else {
                Routes.AllSet
            }
            navController.navigate(next) {
                popUpTo(Routes.FocusAccess) { inclusive = true }
            }
        }
    }

    ScreenScaffold(
        hero = true,
        topBar = { ScreenHeader(title = ProductCopy.FOCUS_ACCESS_HEADER, onBack = onBack) },
    ) {
        PermissionPrimer(
            iconRes = R.drawable.ic_focus_shield,
            title = ProductCopy.FOCUS_ACCESS_TITLE,
            body = ProductCopy.FOCUS_ACCESS_BODY,
            primaryLabel = ProductCopy.FOCUS_ACCESS_PRIMARY,
            tone = PillTone.Sync,
            status = when {
                state.dndAccessStillDenied -> ProductCopy.FOCUS_ACCESS_STILL_DENIED
                else -> ProductCopy.FOCUS_ACCESS_HINT
            },
            onPrimary = {
                viewModel.onOpenedDndSettings()
                context.startActivity(DndAccessSettings.intent(context.packageName))
            },
        )
    }
}
