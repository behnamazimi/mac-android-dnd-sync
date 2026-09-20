package com.dndsync.android.ui.designsystem

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

/**
 * Icon + title + body + primary CTA (+ optional status line and quiet secondary link).
 * Shared by every "explain why, then ask" screen: onboarding's Do Not Disturb
 * access and Notifications-access screens, and Home's inline access-repair
 * card content — so the reason and the ask always read identically wherever
 * they appear.
 */
@Composable
fun PermissionPrimer(
    iconRes: Int,
    title: String,
    body: String,
    primaryLabel: String,
    onPrimary: () -> Unit,
    modifier: Modifier = Modifier,
    tone: PillTone = PillTone.Sync,
    centered: Boolean = true,
    status: String? = null,
    secondaryLabel: String? = null,
    onSecondary: (() -> Unit)? = null,
    extra: @Composable ColumnScope.() -> Unit = {},
) {
    val align = if (centered) Alignment.CenterHorizontally else Alignment.Start
    val textAlign = if (centered) TextAlign.Center else TextAlign.Start
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = align,
        verticalArrangement = Arrangement.spacedBy(InGroup),
    ) {
        StatusIconCircle(
            tone = tone,
            iconRes = iconRes,
            size = 56.dp,
        )
        ScreenTitle(text = title, textAlign = textAlign, modifier = Modifier.fillMaxWidth())
        BodyText(text = body, textAlign = textAlign, modifier = Modifier.fillMaxWidth())
        if (!status.isNullOrBlank()) {
            MetaText(text = status, textAlign = textAlign, modifier = Modifier.fillMaxWidth())
        }
        extra()
        PrimaryButton(label = primaryLabel, onClick = onPrimary)
        if (secondaryLabel != null && onSecondary != null) {
            QuietButton(label = secondaryLabel, onClick = onSecondary)
        }
    }
}
