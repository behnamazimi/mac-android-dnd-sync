package com.dndsync.android.ui.designsystem

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.HorizontalDivider
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dndsync.android.ui.copy.HomeCopy
import com.dndsync.android.ui.theme.DndSyncTheme

/**
 * Presentation-only row shape — domain mapping (from last-sync fields on Pair session)
 * etc.) lives in `ui/home/RecentActivity.kt`, kept out of this generic component.
 */
data class ActivityRow(val timeLabel: String, val line: String)

/** Home's short sync trail — the evidence that stands in for a manual on/off control. */
@Composable
fun RecentActivityList(items: List<ActivityRow>, modifier: Modifier = Modifier) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        MetaLabel(text = HomeCopy.RECENT_ACTIVITY, color = DndSyncTheme.colors.inkFaint)
        if (items.isEmpty()) {
            BodyText(text = HomeCopy.RECENT_ACTIVITY_EMPTY)
        } else {
            items.forEachIndexed { index, row ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    BodyText(
                        text = row.line,
                        textAlign = TextAlign.Start,
                    )
                    MetaLabel(text = row.timeLabel, color = DndSyncTheme.colors.inkFaint)
                }
                if (index != items.lastIndex) {
                    HorizontalDivider(color = DndSyncTheme.colors.line)
                }
            }
        }
    }
}
