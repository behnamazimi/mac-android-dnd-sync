package com.dndsync.android.ui.designsystem

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.dndsync.android.R
import com.dndsync.android.ui.copy.ProductCopy
import com.dndsync.android.ui.theme.DndSyncTheme

val ScreenInset = 16.dp
val BetweenGroups = 24.dp
private val ContentMaxWidth = 600.dp
private val BrandBadgeSize = 40.dp

@Composable
fun ScreenScaffold(
    bottomBar: @Composable (() -> Unit)? = null,
    topBar: @Composable (() -> Unit)? = null,
    hero: Boolean = false,
    content: @Composable ColumnScope.() -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .padding(ScreenInset),
    ) {
        Column(
            modifier = Modifier
                .widthIn(max = ContentMaxWidth)
                .fillMaxSize()
                .align(Alignment.TopCenter),
        ) {
            if (topBar != null) {
                topBar()
                Spacer(modifier = Modifier.height(BetweenGroups))
            }
            BoxWithConstraints(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
            ) {
                val arrangement = if (hero) {
                    Arrangement.spacedBy(BetweenGroups, Alignment.CenterVertically)
                } else {
                    Arrangement.spacedBy(BetweenGroups)
                }
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = maxHeight)
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = arrangement,
                    content = content,
                )
            }
            if (bottomBar != null) {
                Spacer(modifier = Modifier.height(BetweenGroups))
                bottomBar()
            }
        }
    }
}

@Composable
fun SectionGroup(
    modifier: Modifier = Modifier,
    horizontalAlignment: Alignment.Horizontal = Alignment.Start,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(InGroup),
        horizontalAlignment = horizontalAlignment,
        content = content,
    )
}

@Composable
fun BrandMark(modifier: Modifier = Modifier, size: Dp = 32.dp, badged: Boolean = false) {
    val image = @Composable {
        Image(
            painter = painterResource(R.drawable.ic_brand),
            contentDescription = null,
            modifier = Modifier.size(size),
        )
    }
    if (badged) {
        Box(
            modifier = modifier
                .size(BrandBadgeSize)
                .clip(CircleShape)
                .background(DndSyncTheme.colors.card),
            contentAlignment = Alignment.Center,
        ) {
            image()
        }
    } else {
        Box(modifier = modifier, contentAlignment = Alignment.Center) {
            image()
        }
    }
}

/** Home's top row: brand mark, app name, settings entry point. */
@Composable
fun BrandHeader(title: String, onSettings: (() -> Unit)? = null) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(InGroup),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BrandMark(size = 32.dp, badged = true)
        Text(
            text = title,
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.headlineSmall,
            color = MaterialTheme.colorScheme.onSurface,
        )
        if (onSettings != null) {
            IconButton(onClick = onSettings, modifier = Modifier.size(MinTap)) {
                Icon(
                    painter = painterResource(R.drawable.ic_settings),
                    contentDescription = ProductCopy.SETTINGS,
                    tint = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.size(24.dp),
                )
            }
        }
    }
}

/** A back chevron + screen title — used by every non-Home, non-onboarding-root screen. */
@Composable
fun ScreenHeader(title: String, onBack: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(InGroup),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = onBack, modifier = Modifier.size(MinTap)) {
            Icon(
                painter = painterResource(R.drawable.ic_back),
                contentDescription = ProductCopy.BACK,
                tint = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.size(24.dp),
            )
        }
        ScreenTitle(text = title, modifier = Modifier.weight(1f))
    }
}

@Preview(showBackground = true)
@Preview(showBackground = true, uiMode = android.content.res.Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun BrandMarkPreview() {
    DndSyncTheme {
        BrandMark(size = 32.dp, badged = true)
    }
}
