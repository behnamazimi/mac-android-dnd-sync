package com.dndsync.android.ui.designsystem

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dndsync.android.ui.copy.ProductCopy
import com.dndsync.android.ui.theme.DndChipShape
import com.dndsync.android.ui.theme.DndSyncTheme

val ChipShape = DndChipShape

enum class PillTone { Neutral, Ok, Sync, Warn, Err }

/** A small status pill. Connection path, diagnostics booleans, and similar. */
@Composable
fun StatusPill(label: String, tone: PillTone, modifier: Modifier = Modifier) {
    val colors = DndSyncTheme.colors
    val (fill, content, border) = when (tone) {
        PillTone.Neutral -> Triple(colors.card, colors.inkSoft, colors.line)
        PillTone.Ok -> Triple(colors.tealSoft, colors.teal, colors.teal.copy(alpha = 0.3f))
        PillTone.Sync -> Triple(colors.tealSoft, colors.teal, colors.teal.copy(alpha = 0.3f))
        PillTone.Warn -> Triple(colors.amberSoft, colors.amber, colors.amber.copy(alpha = 0.3f))
        PillTone.Err -> Triple(colors.errorSoft, colors.error, colors.error.copy(alpha = 0.3f))
    }
    Surface(
        modifier = modifier,
        shape = ChipShape,
        color = fill,
        contentColor = content,
        border = BorderStroke(1.dp, border),
    ) {
        MetaLabel(
            text = label,
            color = content,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
        )
    }
}

enum class ConnectionPath { Lan, Cloud, None }

/** The Home status card's live-connectivity chip. Activity rows name who flipped Do Not Disturb, not this path. */
@Composable
fun ConnectionPathChip(path: ConnectionPath, modifier: Modifier = Modifier) {
    when (path) {
        ConnectionPath.Lan -> StatusPill(label = ProductCopy.PATH_NEARBY, tone = PillTone.Sync, modifier = modifier)
        ConnectionPath.Cloud -> StatusPill(label = ProductCopy.PATH_INTERNET, tone = PillTone.Sync, modifier = modifier)
        ConnectionPath.None -> StatusPill(label = ProductCopy.NOT_CONNECTED, tone = PillTone.Neutral, modifier = modifier)
    }
}
