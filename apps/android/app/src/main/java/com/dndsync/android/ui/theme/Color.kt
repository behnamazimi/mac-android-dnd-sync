package com.dndsync.android.ui.theme

import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/**
 * Raw token values. [DndSyncColors] (theme-aware, picked by [DndSyncTheme]) is what
 * screens should read — these objects exist only to build the light/dark sets below.
 */
private object LightTokens {
    val Paper = Color(0xFFF6F4F0)
    val Card = Color(0xFFFFFFFF)
    val Ink = Color(0xFF12121F)
    val InkSoft = Color(0xFF5A5F6E)
    val InkFaint = Color(0xFF8991A0)
    val Line = Color(0xFFE1DED6)
    val Navy = Color(0xFF1B1748)
    val Teal = Color(0xFF0C8F80)
    val TealSoft = Color(0xFFDCEEEB)
    val Amber = Color(0xFFA5690C)
    val AmberSoft = Color(0xFFF3E3C9)
    val Error = Color(0xFFB53A2E)
    val ErrorSoft = Color(0xFFF6DDD6)
    val OnAccent = Color.White
    val Shadow = Color(0xFF0B1020)
}

private object DarkTokens {
    val Paper = Color(0xFF16141C)
    val Card = Color(0xFF221F2A)
    val Ink = Color(0xFFF3EEE6)
    val InkSoft = Color(0xFFC9C4BB)
    val InkFaint = Color(0xFF8E8982)
    val Line = Color(0x1AF3EEE6)
    val Navy = Color(0xFF9B97E8)
    val Teal = Color(0xFF5CBCB0)
    val TealSoft = Color(0xFF1A3330)
    val Amber = Color(0xFFEEAB4D)
    val AmberSoft = Color(0xFF3C3018)
    val Error = Color(0xFFE2735A)
    val ErrorSoft = Color(0xFF3A201C)
    val OnAccent = Color(0xFF16141C)
    val Shadow = Color(0x00000000)
}

/**
 * Tokens beyond what Material3's [androidx.compose.material3.ColorScheme] slots cover —
 * notably `teal` (the sync/connection accent) and `amber` (reserved for DND-on/active
 * state indicators, kept semantically separate from general button color). Read via
 * `DndSyncTheme.colors` inside a [DndSyncTheme].
 */
data class DndSyncColors(
    val paper: Color,
    val card: Color,
    val ink: Color,
    val inkSoft: Color,
    val inkFaint: Color,
    val line: Color,
    val teal: Color,
    val tealSoft: Color,
    val amber: Color,
    val amberSoft: Color,
    val error: Color,
    val errorSoft: Color,
    val onAccent: Color,
    val shadow: Color,
)

internal fun lightDndSyncColors() = DndSyncColors(
    paper = LightTokens.Paper,
    card = LightTokens.Card,
    ink = LightTokens.Ink,
    inkSoft = LightTokens.InkSoft,
    inkFaint = LightTokens.InkFaint,
    line = LightTokens.Line,
    teal = LightTokens.Teal,
    tealSoft = LightTokens.TealSoft,
    amber = LightTokens.Amber,
    amberSoft = LightTokens.AmberSoft,
    error = LightTokens.Error,
    errorSoft = LightTokens.ErrorSoft,
    onAccent = LightTokens.OnAccent,
    shadow = LightTokens.Shadow,
)

internal fun darkDndSyncColors() = DndSyncColors(
    paper = DarkTokens.Paper,
    card = DarkTokens.Card,
    ink = DarkTokens.Ink,
    inkSoft = DarkTokens.InkSoft,
    inkFaint = DarkTokens.InkFaint,
    line = DarkTokens.Line,
    teal = DarkTokens.Teal,
    tealSoft = DarkTokens.TealSoft,
    amber = DarkTokens.Amber,
    amberSoft = DarkTokens.AmberSoft,
    error = DarkTokens.Error,
    errorSoft = DarkTokens.ErrorSoft,
    onAccent = DarkTokens.OnAccent,
    shadow = DarkTokens.Shadow,
)

internal fun lightNavy() = LightTokens.Navy
internal fun darkNavy() = DarkTokens.Navy

val LocalDndSyncColors = staticCompositionLocalOf { lightDndSyncColors() }
