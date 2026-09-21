package com.dndsync.android.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.dndsync.android.BuildConfig
import com.dndsync.android.pair.PairSession
import com.dndsync.android.ui.diagnostics.DiagnosticsScreen
import com.dndsync.android.ui.home.HomeScreen
import com.dndsync.android.ui.onboarding.AllSetScreen
import com.dndsync.android.ui.onboarding.ConnectToMacScreen
import com.dndsync.android.ui.onboarding.ConnectingScreen
import com.dndsync.android.ui.onboarding.FocusAccessScreen
import com.dndsync.android.ui.onboarding.NotificationsAccessScreen
import com.dndsync.android.ui.onboarding.WelcomeScreen
import com.dndsync.android.ui.settings.AboutScreen
import com.dndsync.android.ui.settings.LicensesScreen
import com.dndsync.android.ui.settings.RepairConfirmScreen
import com.dndsync.android.ui.settings.SettingsScreen
import com.dndsync.android.ui.settings.UnpairConfirmScreen

/**
 * The whole app's route graph. Back-stack rules that encode product decisions live
 * here, inline at each `navigate()` call, rather than in a separate router class —
 * navigation-compose's own APIs (`popUpTo`, `inclusive`) are expressive enough that a
 * hand-rolled state machine (the pre-redesign `AppRouting`) would only add a layer of
 * indirection over what this file already says directly.
 */
@Composable
fun DndSyncNavHost(
    startDestination: String,
    pairSession: PairSession,
    modifier: Modifier = Modifier,
) {
    val navController = rememberNavController()
    val cloud by pairSession.ui.collectAsStateWithLifecycle()
    val current by navController.currentBackStackEntryAsState()
    LaunchedEffect(cloud, current?.destination?.route) {
        val route = current?.destination?.route
        if (AndroidRouting.shouldResetToWelcome(pairSession.hasStoredPair, route)) {
            navController.navigate(Routes.Welcome) { popUpTo(0) { inclusive = true } }
        }
    }
    NavHost(navController = navController, startDestination = startDestination, modifier = modifier) {
        composable(Routes.Welcome) {
            WelcomeScreen(
                onContinue = { navController.navigate(Routes.connectToMac(Origin.Onboarding)) },
            )
        }

        composable(
            Routes.ConnectToMacPattern,
            arguments = listOf(navArgument(Routes.OriginArg) { type = NavType.StringType }),
        ) { entry ->
            val origin = originArg(entry)
            ConnectToMacScreen(
                origin = origin,
                onBack = { navController.popBackStack() },
                onConnecting = { navController.navigate(Routes.connecting(origin)) },
            )
        }

        composable(
            Routes.ConnectingPattern,
            arguments = listOf(navArgument(Routes.OriginArg) { type = NavType.StringType }),
        ) { entry ->
            ConnectingScreen(
                origin = originArg(entry),
                navController = navController,
                onBack = { navController.popBackStack() },
            )
        }

        composable(Routes.FocusAccess) {
            FocusAccessScreen(navController = navController, onBack = { navController.popBackStack() })
        }

        composable(Routes.NotificationsAccess) {
            NotificationsAccessScreen(navController = navController, onBack = { navController.popBackStack() })
        }

        composable(Routes.AllSet) {
            AllSetScreen(navController = navController)
        }

        composable(Routes.Home) {
            HomeScreen(onSettings = { navController.navigate(Routes.Settings) })
        }

        composable(Routes.Settings) {
            SettingsScreen(
                onBack = { navController.popBackStack() },
                onRepair = { navController.navigate(Routes.RepairConfirm) },
                onUnpair = { navController.navigate(Routes.UnpairConfirm) },
                onAbout = { navController.navigate(Routes.About) },
            )
        }

        composable(Routes.RepairConfirm) {
            RepairConfirmScreen(
                onBack = { navController.popBackStack() },
                onStartNewPairing = { navController.navigate(Routes.connectToMac(Origin.Repair)) },
            )
        }

        composable(Routes.UnpairConfirm) {
            UnpairConfirmScreen(
                onBack = { navController.popBackStack() },
                onUnpaired = {
                    navController.navigate(Routes.Welcome) { popUpTo(0) { inclusive = true } }
                },
            )
        }

        composable(Routes.About) {
            AboutScreen(
                debugDiagnosticsAvailable = BuildConfig.DEBUG,
                onBack = { navController.popBackStack() },
                onLicenses = { navController.navigate(Routes.Licenses) },
                onDiagnostics = { navController.navigate(Routes.Diagnostics) },
            )
        }

        composable(Routes.Licenses) {
            LicensesScreen(onBack = { navController.popBackStack() })
        }

        // Route itself is absent from the graph in release builds — not just its
        // on/off buttons — so it's unreachable however someone tries to get there.
        if (BuildConfig.DEBUG) {
            composable(Routes.Diagnostics) {
                DiagnosticsScreen(onBack = { navController.popBackStack() })
            }
        }
    }
}

private fun originArg(entry: androidx.navigation.NavBackStackEntry): Origin =
    Origin.valueOf(entry.arguments?.getString(Routes.OriginArg) ?: Origin.Onboarding.name)
