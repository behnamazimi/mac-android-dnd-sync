package com.dndsync.android.ui.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import com.dndsync.android.BuildConfig
import com.dndsync.android.ui.copy.Distribution
import com.dndsync.android.ui.copy.ProductCopy
import com.dndsync.android.ui.designsystem.BodyText
import com.dndsync.android.ui.designsystem.BrandMark
import com.dndsync.android.ui.designsystem.InGroup
import com.dndsync.android.ui.designsystem.MetaText
import com.dndsync.android.ui.designsystem.ScreenHeader
import com.dndsync.android.ui.designsystem.ScreenScaffold
import com.dndsync.android.ui.designsystem.ScreenTitle
import com.dndsync.android.ui.designsystem.SectionGroup
import com.dndsync.android.ui.designsystem.SettingsRow

/**
 * Version, the app's strongest privacy claim in plain language, and — debug builds
 * only — the door to Diagnostics. This is where a normal user would go looking for a
 * privacy answer, so it states one outright rather than burying it in a policy link.
 */
@Composable
fun AboutScreen(
    debugDiagnosticsAvailable: Boolean,
    onBack: () -> Unit,
    onLicenses: () -> Unit,
    onDiagnostics: () -> Unit,
) {
    val uriHandler = LocalUriHandler.current
    ScreenScaffold {
        ScreenHeader(title = ProductCopy.ABOUT_TITLE, onBack = onBack)
        Row(
            horizontalArrangement = Arrangement.spacedBy(InGroup),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            BrandMark(size = 40.dp)
            ScreenTitle(text = "${ProductCopy.APP_NAME} ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})")
        }
        SectionGroup {
            MetaText(ProductCopy.WHAT_WE_STORE_SECTION)
            BodyText(ProductCopy.WHAT_WE_STORE_BODY)
        }
        SectionGroup {
            // Not on the Play Store yet — same GitHub Release page as the Connect
            // screen's escape hatch, kept here for the later "where did I get
            // this?" lookup.
            SettingsRow(
                label = ProductCopy.DOWNLOAD_MAC_APP,
                onClick = { uriHandler.openUri(Distribution.GITHUB_RELEASES) },
            )
            SettingsRow(label = ProductCopy.OPEN_SOURCE_LICENSES, onClick = onLicenses)
            if (debugDiagnosticsAvailable) {
                SettingsRow(label = ProductCopy.DIAGNOSTICS, onClick = onDiagnostics)
            }
        }
    }
}
