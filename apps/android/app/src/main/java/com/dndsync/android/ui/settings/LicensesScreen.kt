package com.dndsync.android.ui.settings

import android.content.res.AssetManager
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import com.dndsync.android.ui.copy.ProductCopy
import com.dndsync.android.ui.designsystem.BodyText
import com.dndsync.android.ui.designsystem.ScreenHeader
import com.dndsync.android.ui.designsystem.ScreenScaffold
import com.dndsync.android.ui.designsystem.ScreenTitle
import com.dndsync.android.ui.designsystem.SectionGroup

private data class LicenseSection(val title: String, val assetPath: String)

private val LicenseSections = listOf(
    LicenseSection(ProductCopy.LICENSE_INTER, "fonts/OFL-Inter.txt"),
)

@Composable
fun LicensesScreen(onBack: () -> Unit) {
    val assets = LocalContext.current.assets
    val bodies = remember(assets) {
        LicenseSections.map { it.title to assets.readText(it.assetPath) }
    }

    ScreenScaffold {
        ScreenHeader(title = ProductCopy.OPEN_SOURCE_LICENSES, onBack = onBack)
        bodies.forEach { (title, body) ->
            SectionGroup {
                ScreenTitle(text = title)
                BodyText(text = body)
            }
        }
    }
}

private fun AssetManager.readText(path: String): String =
    open(path).bufferedReader().use { it.readText() }
