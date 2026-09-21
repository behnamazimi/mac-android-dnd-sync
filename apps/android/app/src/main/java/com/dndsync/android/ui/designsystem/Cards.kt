package com.dndsync.android.ui.designsystem

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.dndsync.android.R
import com.dndsync.android.ui.theme.DndCardShape
import com.dndsync.android.ui.theme.DndSyncTheme

val CardShape = DndCardShape
val CardPadding = 20.dp
val InGroup = 8.dp
private val RowInset = PaddingValues(horizontal = 0.dp, vertical = 0.dp)

@Composable
fun Card(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    val scheme = MaterialTheme.colorScheme
    val shadow = DndSyncTheme.colors.shadow
    val dark = isSystemInDarkTheme()
    Surface(
        modifier = modifier
            .fillMaxWidth()
            .then(
                if (dark) {
                    Modifier
                } else {
                    Modifier.shadow(
                        elevation = 8.dp,
                        shape = CardShape,
                        clip = false,
                        ambientColor = shadow.copy(alpha = 0.08f),
                        spotColor = shadow.copy(alpha = 0.10f),
                    )
                },
            ),
        shape = CardShape,
        color = scheme.surfaceVariant,
        contentColor = scheme.onSurface,
        border = BorderStroke(1.dp, scheme.onSurface.copy(alpha = 0.08f)),
        shadowElevation = 0.dp,
        tonalElevation = 0.dp,
    ) {
        Column(
            modifier = Modifier.padding(CardPadding),
            verticalArrangement = Arrangement.spacedBy(InGroup),
            content = content,
        )
    }
}

/** A 48dp tinted circle holding an icon or a spinner — pass as [StatusCard]'s `leading`. */
@Composable
fun StatusIconCircle(
    tone: PillTone,
    iconRes: Int?,
    modifier: Modifier = Modifier,
    size: Dp = 48.dp,
) {
    val colors = DndSyncTheme.colors
    val (fill, content) = when (tone) {
        PillTone.Neutral -> colors.card to colors.inkSoft
        PillTone.Ok, PillTone.Sync -> colors.tealSoft to colors.teal
        PillTone.Warn -> colors.amberSoft to colors.amber
        PillTone.Err -> colors.errorSoft to colors.error
    }
    Box(
        modifier = modifier
            .size(size)
            .background(fill, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        if (iconRes != null) {
            Icon(
                painter = painterResource(iconRes),
                contentDescription = null,
                tint = content,
                modifier = Modifier.size(size * 0.5f),
            )
        } else {
            CircularProgressIndicator(
                modifier = Modifier.size(size * 0.45f),
                color = content,
                strokeWidth = 2.dp,
            )
        }
    }
}

/**
 * The Home hub's one status card — same layout across all four states; only [tone],
 * [leading], copy and the optional CTA change. See `ui/home/HomeStatus.kt`.
 */
@Composable
fun StatusCard(
    leading: @Composable () -> Unit,
    tone: PillTone,
    headline: String,
    subline: String,
    modifier: Modifier = Modifier,
    trailingChip: @Composable (() -> Unit)? = null,
    ctaLabel: String? = null,
    onCta: (() -> Unit)? = null,
) {
    val colors = DndSyncTheme.colors
    val fill = when (tone) {
        PillTone.Neutral -> colors.card
        PillTone.Ok, PillTone.Sync -> colors.tealSoft
        PillTone.Warn -> colors.amberSoft
        PillTone.Err -> colors.errorSoft
    }
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = CardShape,
        color = fill,
    ) {
        Column(
            modifier = Modifier.padding(CardPadding),
            verticalArrangement = Arrangement.spacedBy(InGroup),
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(InGroup),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                leading()
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(text = headline, style = MaterialTheme.typography.headlineSmall)
                    Text(
                        text = subline,
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.inkSoft,
                    )
                }
            }
            if (trailingChip != null) {
                trailingChip()
            }
            if (ctaLabel != null && onCta != null) {
                PrimaryButton(label = ctaLabel, onClick = onCta)
            }
        }
    }
}

@Composable
fun SettingsRow(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    destructive: Boolean = false,
    supporting: String? = null,
    trailing: @Composable RowScope.() -> Unit = {},
) {
    val scheme = MaterialTheme.colorScheme
    val content = if (destructive) scheme.error else scheme.onSurface
    TextButton(
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = MinTap),
        shape = ChipShape,
        contentPadding = RowInset,
        colors = ButtonDefaults.textButtonColors(contentColor = content),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (supporting == null) {
                Text(text = label, style = MaterialTheme.typography.bodyLarge)
            } else {
                Column(modifier = Modifier.weight(1f)) {
                    Text(text = label, style = MaterialTheme.typography.bodyLarge)
                    Text(
                        text = supporting,
                        style = MaterialTheme.typography.bodyMedium,
                        color = DndSyncTheme.colors.inkSoft,
                    )
                }
            }
            trailing()
        }
    }
}

@Composable
fun SettingsInfoRow(
    label: String,
    modifier: Modifier = Modifier,
    trailing: @Composable RowScope.() -> Unit = {},
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = MinTap),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.weight(1f),
        )
        trailing()
    }
}

@Composable
fun SettingsSwitchRow(
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = MinTap),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.weight(1f),
        )
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Preview(showBackground = true)
@Preview(showBackground = true, uiMode = android.content.res.Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun StatusCardPreview() {
    DndSyncTheme {
        StatusCard(
            leading = {
                StatusIconCircle(tone = PillTone.Ok, iconRes = R.drawable.ic_check_circle)
            },
            tone = PillTone.Ok,
            headline = "Do Not Disturb is off",
            subline = "Synced on both devices",
            trailingChip = { ConnectionPathChip(path = ConnectionPath.Lan) },
        )
    }
}
