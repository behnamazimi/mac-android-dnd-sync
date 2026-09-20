package com.dndsync.android.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

/**
 * Status/navigation bar icon contrast is handled once in `MainActivity` via
 * `enableEdgeToEdge(SystemBarStyle.auto(...))`, which already follows the system
 * light/dark setting — this composable only drives Compose-level theming.
 */
@Composable
fun DndSyncTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colors = if (darkTheme) darkDndSyncColors() else lightDndSyncColors()
    val navy = if (darkTheme) darkNavy() else lightNavy()

    CompositionLocalProvider(LocalDndSyncColors provides colors) {
        MaterialTheme(
            colorScheme = dndSyncColorScheme(colors, navy, darkTheme),
            typography = dndSyncTypography(),
            shapes = dndSyncShapes(),
        ) {
            Surface(
                modifier = Modifier.fillMaxSize(),
                color = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.onSurface,
                content = content,
            )
        }
    }
}

/** Extended, theme-aware tokens beyond Material3's [ColorScheme] slots. */
object DndSyncTheme {
    val colors: DndSyncColors
        @Composable
        @ReadOnlyComposable
        get() = LocalDndSyncColors.current
}

private fun dndSyncColorScheme(colors: DndSyncColors, navy: Color, darkTheme: Boolean): ColorScheme {
    val ink = colors.ink
    val primary = if (darkTheme) colors.teal else navy
    val onPrimary = colors.onAccent
    val primaryContainer = primary.copy(alpha = 0.12f)
    val base = if (darkTheme) {
        androidx.compose.material3.darkColorScheme()
    } else {
        androidx.compose.material3.lightColorScheme()
    }
    return base.copy(
        primary = primary,
        onPrimary = onPrimary,
        primaryContainer = primaryContainer,
        onPrimaryContainer = ink,
        secondary = colors.teal,
        onSecondary = colors.onAccent,
        secondaryContainer = colors.tealSoft,
        onSecondaryContainer = colors.teal,
        tertiary = colors.amber,
        onTertiary = colors.onAccent,
        tertiaryContainer = colors.amberSoft,
        onTertiaryContainer = colors.amber,
        background = colors.paper,
        onBackground = ink,
        surface = colors.paper,
        onSurface = ink,
        surfaceVariant = colors.card,
        onSurfaceVariant = colors.inkSoft,
        surfaceTint = Color.Transparent,
        surfaceBright = colors.card,
        surfaceDim = colors.paper,
        surfaceContainerLowest = colors.paper,
        surfaceContainerLow = colors.card,
        surfaceContainer = colors.card,
        surfaceContainerHigh = colors.card,
        surfaceContainerHighest = colors.card,
        inverseSurface = ink,
        inverseOnSurface = colors.paper,
        inversePrimary = colors.onAccent,
        outline = colors.line,
        outlineVariant = colors.line.copy(alpha = 0.6f),
        scrim = Color.Black.copy(alpha = 0.5f),
        error = colors.error,
        onError = colors.onAccent,
        errorContainer = colors.errorSoft,
        onErrorContainer = colors.error,
    )
}
