package com.dndsync.android.ui.diagnostics

import android.widget.Toast
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.dndsync.android.ui.designsystem.InGroup
import com.dndsync.android.ui.designsystem.DiagnosticsLine
import com.dndsync.android.ui.designsystem.PillTone
import com.dndsync.android.ui.designsystem.PrimaryButton
import com.dndsync.android.ui.designsystem.ScreenHeader
import com.dndsync.android.ui.designsystem.ScreenScaffold
import com.dndsync.android.ui.designsystem.SecondaryButton
import com.dndsync.android.ui.designsystem.SectionGroup
import com.dndsync.android.ui.designsystem.StatusPill

@Composable
fun DiagnosticsScreen(
    onBack: () -> Unit,
    viewModel: DiagnosticsViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val clipboard = LocalClipboardManager.current
    val context = LocalContext.current

    LifecycleResumeEffect(Unit) {
        viewModel.refreshPermissions()
        onPauseOrDispose { }
    }

    ScreenScaffold {
        ScreenHeader(title = "Diagnostics", onBack = onBack)
        StatusPill(label = "DEBUG BUILD ONLY", tone = PillTone.Err)
        SectionGroup {
            DiagnosticsReport.lines(state).forEach { line ->
                SelectionContainer { DiagnosticsLine(text = line) }
            }
            SecondaryButton(
                label = "Copy all",
                onClick = {
                    clipboard.setText(AnnotatedString(DiagnosticsReport.build(state)))
                    Toast.makeText(context, "Copied", Toast.LENGTH_SHORT).show()
                },
            )
        }
        SectionGroup {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(InGroup),
            ) {
                PrimaryButton(
                    label = "On",
                    onClick = viewModel::turnOn,
                    enabled = state.policyAccessGranted,
                    modifier = Modifier.weight(1f),
                )
                PrimaryButton(
                    label = "Off",
                    onClick = viewModel::turnOff,
                    enabled = state.policyAccessGranted,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}
