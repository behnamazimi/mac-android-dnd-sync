package com.dndsync.android.ui.designsystem

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import com.dndsync.android.ui.theme.DndSyncTheme
import com.dndsync.android.ui.theme.MetaLabelStyle

@Composable
fun ScreenTitle(
    text: String,
    modifier: Modifier = Modifier,
    textAlign: TextAlign = TextAlign.Unspecified,
) {
    Text(
        text = text,
        modifier = modifier,
        style = MaterialTheme.typography.headlineSmall,
        color = MaterialTheme.colorScheme.onSurface,
        textAlign = textAlign,
    )
}

@Composable
fun DisplayTitle(
    text: String,
    modifier: Modifier = Modifier,
    textAlign: TextAlign = TextAlign.Unspecified,
) {
    Text(
        text = text,
        modifier = modifier,
        style = MaterialTheme.typography.displaySmall,
        color = MaterialTheme.colorScheme.onSurface,
        textAlign = textAlign,
    )
}

@Composable
fun BodyText(
    text: String,
    modifier: Modifier = Modifier,
    textAlign: TextAlign = TextAlign.Unspecified,
) {
    Text(
        text = text,
        modifier = modifier,
        style = MaterialTheme.typography.bodyLarge,
        color = DndSyncTheme.colors.inkSoft,
        textAlign = textAlign,
    )
}

@Composable
fun MetaText(
    text: String,
    modifier: Modifier = Modifier,
    textAlign: TextAlign = TextAlign.Unspecified,
) {
    Text(
        text = text,
        modifier = modifier,
        style = MaterialTheme.typography.bodyMedium,
        color = DndSyncTheme.colors.inkFaint,
        textAlign = textAlign,
    )
}

@Composable
fun ErrorText(text: String?, modifier: Modifier = Modifier, textAlign: TextAlign = TextAlign.Unspecified) {
    if (text.isNullOrBlank()) {
        return
    }
    Text(
        text = text,
        modifier = modifier.semantics { liveRegion = LiveRegionMode.Assertive },
        style = MaterialTheme.typography.bodyLarge,
        color = MaterialTheme.colorScheme.error,
        maxLines = 4,
        overflow = TextOverflow.Ellipsis,
        textAlign = textAlign,
    )
}

/** Chips, section labels, timestamps — Inter meta with tracking. */
@Composable
fun MetaLabel(
    text: String,
    modifier: Modifier = Modifier,
    color: Color = DndSyncTheme.colors.inkSoft,
) {
    Text(
        text = text,
        modifier = modifier,
        style = MetaLabelStyle,
        color = color,
    )
}

/** Debug report lines only — platform monospace, not a bundled face. */
@Composable
fun DiagnosticsLine(
    text: String,
    modifier: Modifier = Modifier,
    color: Color = DndSyncTheme.colors.inkSoft,
) {
    Text(
        text = text,
        modifier = modifier,
        style = MetaLabelStyle.copy(fontFamily = FontFamily.Monospace),
        color = color,
    )
}
