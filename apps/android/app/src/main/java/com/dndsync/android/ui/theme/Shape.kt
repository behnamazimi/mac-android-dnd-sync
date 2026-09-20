package com.dndsync.android.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

val DndChipShape = RoundedCornerShape(8.dp)
val DndButtonShape = RoundedCornerShape(16.dp)
val DndCardShape = RoundedCornerShape(24.dp)

internal fun dndSyncShapes() = Shapes(
    extraSmall = DndChipShape,
    small = DndChipShape,
    medium = DndButtonShape,
    large = DndCardShape,
    extraLarge = DndCardShape,
)
