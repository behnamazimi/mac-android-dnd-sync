@file:OptIn(ExperimentalTextApi::class)

package com.dndsync.android.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.dndsync.android.R

/** Single product face — Regular and Semibold only. */
val InterFamily = FontFamily(
    Font(
        R.font.inter_variable,
        weight = FontWeight.Normal,
        variationSettings = FontVariation.Settings(FontVariation.weight(400)),
    ),
    Font(
        R.font.inter_variable,
        weight = FontWeight.SemiBold,
        variationSettings = FontVariation.Settings(FontVariation.weight(600)),
    ),
)

private val DisplayStyle = TextStyle(
    fontFamily = InterFamily,
    fontSize = 32.sp,
    lineHeight = 40.sp,
    fontWeight = FontWeight.SemiBold,
    letterSpacing = (-0.4).sp,
)

private val TitleStyle = TextStyle(
    fontFamily = InterFamily,
    fontSize = 22.sp,
    lineHeight = 28.sp,
    fontWeight = FontWeight.SemiBold,
    letterSpacing = (-0.2).sp,
)

private val BodyStyle = TextStyle(
    fontFamily = InterFamily,
    fontSize = 16.sp,
    lineHeight = 24.sp,
    fontWeight = FontWeight.Normal,
    letterSpacing = 0.sp,
)

private val MetaStyle = TextStyle(
    fontFamily = InterFamily,
    fontSize = 12.sp,
    lineHeight = 16.sp,
    fontWeight = FontWeight.Normal,
    letterSpacing = 0.4.sp,
)

/** Chips, section labels, timestamps — Inter meta, not a third family. */
val MetaLabelStyle = MetaStyle

internal fun dndSyncTypography(): Typography {
    return Typography(
        displayLarge = DisplayStyle,
        displayMedium = DisplayStyle,
        displaySmall = DisplayStyle,
        headlineLarge = DisplayStyle,
        headlineMedium = DisplayStyle,
        headlineSmall = TitleStyle,
        titleLarge = TitleStyle,
        titleMedium = BodyStyle,
        titleSmall = BodyStyle,
        bodyLarge = BodyStyle,
        bodyMedium = MetaStyle,
        bodySmall = MetaStyle,
        labelLarge = BodyStyle,
        labelMedium = MetaStyle,
        labelSmall = MetaStyle,
    )
}
