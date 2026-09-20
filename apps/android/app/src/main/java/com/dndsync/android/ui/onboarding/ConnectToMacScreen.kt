package com.dndsync.android.ui.onboarding

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.dndsync.android.ui.copy.Distribution
import com.dndsync.android.ui.copy.ProductCopy
import com.dndsync.android.ui.designsystem.BodyText
import com.dndsync.android.ui.designsystem.ButtonShape
import com.dndsync.android.ui.designsystem.ErrorText
import com.dndsync.android.ui.designsystem.InGroup
import com.dndsync.android.ui.designsystem.MinTap
import com.dndsync.android.ui.designsystem.PrimaryButton
import com.dndsync.android.ui.designsystem.QuietButton
import com.dndsync.android.ui.designsystem.ScreenHeader
import com.dndsync.android.ui.designsystem.ScreenScaffold
import com.dndsync.android.ui.designsystem.SectionGroup
import com.dndsync.android.ui.navigation.Origin
import com.dndsync.android.ui.pairing.QrScanner

private enum class ConnectTab { Scan, EnterCode }

/**
 * One screen, two tabs. Scan is the default (it's the tangible, exciting part of
 * setup); Enter code is the escape hatch for a denied/missing camera.
 */
@Composable
fun ConnectToMacScreen(
    origin: Origin,
    onBack: () -> Unit,
    onConnecting: () -> Unit,
    viewModel: OnboardingViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val clipboard = LocalClipboardManager.current
    val uriHandler = LocalUriHandler.current

    var tab by rememberSaveable {
        mutableStateOf(if (state.cameraHardwareAvailable) ConnectTab.Scan else ConnectTab.EnterCode)
    }
    var pasteText by rememberSaveable { mutableStateOf("") }
    var showScanner by rememberSaveable { mutableStateOf(false) }

    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        viewModel.onCameraPermissionResult(granted)
        if (granted) showScanner = true
    }

    fun join() {
        if (pasteText.isBlank()) return
        viewModel.pastePayload(pasteText)
        onConnecting()
    }

    if (showScanner) {
        QrScanner(
            modifier = Modifier.fillMaxSize(),
            onQr = { raw ->
                val valid = viewModel.onScannedPayload(raw)
                if (valid) {
                    showScanner = false
                    onConnecting()
                }
                valid
            },
            onFailed = {
                viewModel.onCameraUnavailable()
                showScanner = false
                tab = ConnectTab.EnterCode
            },
            onClose = { showScanner = false },
            onSwitchToPaste = {
                showScanner = false
                tab = ConnectTab.EnterCode
            },
        )
        return
    }

    ScreenScaffold {
        ScreenHeader(
            title = if (origin == Origin.Repair) ProductCopy.CONNECT_REPAIR_TITLE else ProductCopy.CONNECT_TITLE,
            onBack = onBack,
        )
        ConnectTabRow(
            selected = tab,
            cameraAvailable = state.cameraHardwareAvailable,
            onSelect = { tab = it },
        )
        when (tab) {
            ConnectTab.Scan -> SectionGroup {
                BodyText(ProductCopy.SCAN_CAPTION)
                if (state.cameraDenied) {
                    ErrorText(ProductCopy.CAMERA_DENIED)
                }
                if (!state.cameraHardwareAvailable) {
                    ErrorText(ProductCopy.CAMERA_UNAVAILABLE)
                }
                PrimaryButton(
                    label = ProductCopy.TAB_SCAN,
                    onClick = {
                        if (state.cameraGranted) {
                            showScanner = true
                        } else {
                            cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
                        }
                    },
                )
                QuietButton(
                    label = ProductCopy.SCAN_TROUBLE,
                    onClick = { tab = ConnectTab.EnterCode },
                )
            }
            ConnectTab.EnterCode -> SectionGroup {
                BodyText(ProductCopy.ENTER_CODE_BODY)
                OutlinedTextField(
                    value = pasteText,
                    onValueChange = { pasteText = it },
                    placeholder = { Text(ProductCopy.ENTER_CODE_PLACEHOLDER) },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 3,
                    shape = MaterialTheme.shapes.medium,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { join() }),
                )
                if (state.pairError != null) {
                    ErrorText(state.pairError)
                }
                QuietButton(
                    label = ProductCopy.PASTE_FROM_CLIPBOARD,
                    onClick = { clipboard.getText()?.text?.let { pasteText = it } },
                )
                PrimaryButton(
                    label = ProductCopy.JOIN,
                    enabled = pasteText.isNotBlank(),
                    onClick = { join() },
                )
            }
        }
        // Not on the Play Store yet — same escape hatch under both tabs, and on
        // re-pair, since either origin can hit this screen without the Mac app.
        QuietButton(
            label = ProductCopy.DOWNLOAD_MAC_APP,
            onClick = { uriHandler.openUri(Distribution.GITHUB_RELEASES) },
        )
    }
}

@Composable
private fun ConnectTabRow(
    selected: ConnectTab,
    cameraAvailable: Boolean,
    onSelect: (ConnectTab) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .selectableGroup(),
        horizontalArrangement = Arrangement.spacedBy(InGroup),
    ) {
        ConnectTab(
            label = ProductCopy.TAB_SCAN,
            selected = selected == ConnectTab.Scan,
            enabled = cameraAvailable,
            onClick = { onSelect(ConnectTab.Scan) },
            modifier = Modifier.weight(1f),
        )
        ConnectTab(
            label = ProductCopy.TAB_ENTER_CODE,
            selected = selected == ConnectTab.EnterCode,
            enabled = true,
            onClick = { onSelect(ConnectTab.EnterCode) },
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun ConnectTab(
    label: String,
    selected: Boolean,
    enabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val scheme = MaterialTheme.colorScheme
    Surface(
        modifier = modifier
            .heightIn(min = MinTap)
            .selectable(
                selected = selected,
                enabled = enabled,
                role = Role.Tab,
                onClick = onClick,
            ),
        shape = ButtonShape,
        color = when {
            !enabled -> scheme.surfaceVariant.copy(alpha = 0.5f)
            selected -> scheme.primary
            else -> scheme.surfaceVariant
        },
        contentColor = when {
            !enabled -> scheme.onSurface.copy(alpha = 0.38f)
            selected -> scheme.onPrimary
            else -> scheme.onSurface
        },
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = MinTap),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.bodyLarge,
                textAlign = TextAlign.Center,
            )
        }
    }
}
