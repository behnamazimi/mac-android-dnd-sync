package com.dndsync.android.ui.pairing

import android.util.Size
import androidx.camera.core.CameraSelector
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.mlkit.vision.MlKitAnalyzer
import androidx.camera.view.CameraController
import androidx.camera.view.LifecycleCameraController
import androidx.camera.view.PreviewView
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.dndsync.android.R
import com.dndsync.android.ui.copy.ProductCopy
import com.dndsync.android.ui.designsystem.MinTap
import com.dndsync.android.ui.designsystem.ScreenInset
import com.dndsync.android.ui.theme.DndSyncTheme
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import java.util.concurrent.atomic.AtomicBoolean

@Composable
fun QrScanner(
    onQr: (String) -> Boolean,
    onFailed: () -> Unit,
    onClose: () -> Unit,
    onSwitchToPaste: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val colors = DndSyncTheme.colors
    val handled = remember { AtomicBoolean(false) }
    var torchOn by remember { mutableStateOf(false) }
    var hasFlash by remember { mutableStateOf(false) }
    val scanner = remember {
        BarcodeScanning.getClient(
            BarcodeScannerOptions.Builder()
                .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
                .build(),
        )
    }
    val controller = remember {
        LifecycleCameraController(context).apply {
            cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
            imageAnalysisResolutionSelector = ResolutionSelector.Builder()
                .setResolutionStrategy(
                    ResolutionStrategy(
                        Size(1280, 720),
                        ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                    ),
                )
                .build()
        }
    }

    DisposableEffect(lifecycleOwner) {
        val executor = ContextCompat.getMainExecutor(context)
        controller.setImageAnalysisAnalyzer(
            executor,
            MlKitAnalyzer(
                listOf(scanner),
                CameraController.COORDINATE_SYSTEM_VIEW_REFERENCED,
                executor,
            ) { result ->
                val barcodes = result.getValue(scanner) ?: return@MlKitAnalyzer
                val raw = barcodes.firstNotNullOfOrNull { it.rawValue } ?: return@MlKitAnalyzer
                if (handled.get()) {
                    return@MlKitAnalyzer
                }
                if (onQr(raw)) {
                    handled.set(true)
                }
            },
        )
        try {
            controller.bindToLifecycle(lifecycleOwner)
            hasFlash = controller.cameraInfo?.hasFlashUnit() == true
        } catch (_: Exception) {
            onFailed()
        }
        onDispose {
            controller.enableTorch(false)
            controller.clearImageAnalysisAnalyzer()
            controller.unbind()
            scanner.close()
        }
    }

    Box(modifier = modifier.fillMaxSize()) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { viewContext ->
                PreviewView(viewContext).apply {
                    this.controller = controller
                    scaleType = PreviewView.ScaleType.FILL_CENTER
                }
            },
        )
        Box(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.safeDrawing)
                .padding(ScreenInset),
        ) {
            Surface(
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .size(MinTap),
                shape = CircleShape,
                color = colors.card.copy(alpha = 0.92f),
                contentColor = colors.ink,
            ) {
                IconButton(onClick = onClose, modifier = Modifier.size(MinTap)) {
                    Icon(
                        painter = painterResource(R.drawable.ic_close),
                        contentDescription = ProductCopy.CLOSE,
                        tint = colors.ink,
                        modifier = Modifier.size(24.dp),
                    )
                }
            }
            if (hasFlash) {
                Surface(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .size(MinTap),
                    shape = CircleShape,
                    color = colors.card.copy(alpha = 0.92f),
                    contentColor = colors.ink,
                ) {
                    IconButton(
                        onClick = {
                            torchOn = !torchOn
                            controller.enableTorch(torchOn)
                        },
                        modifier = Modifier.size(MinTap),
                    ) {
                        Icon(
                            painter = painterResource(
                                if (torchOn) R.drawable.ic_flash_off else R.drawable.ic_flash_on,
                            ),
                            contentDescription = if (torchOn) {
                                ProductCopy.FLASHLIGHT_TURN_OFF
                            } else {
                                ProductCopy.FLASHLIGHT_TURN_ON
                            },
                            tint = colors.ink,
                            modifier = Modifier.size(24.dp),
                        )
                    }
                }
            }
            Box(
                modifier = Modifier
                    .align(Alignment.Center)
                    .size(240.dp)
                    .border(
                        width = 2.dp,
                        color = Color.White.copy(alpha = 0.92f),
                        shape = MaterialTheme.shapes.large,
                    ),
            )
            Surface(
                modifier = Modifier.align(Alignment.BottomCenter),
                shape = MaterialTheme.shapes.medium,
                color = colors.card.copy(alpha = 0.92f),
                contentColor = colors.ink,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = ProductCopy.SCAN_CAPTION,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                        style = MaterialTheme.typography.bodyLarge,
                        color = colors.ink,
                    )
                    TextButton(onClick = onSwitchToPaste) {
                        Text(
                            text = ProductCopy.PASTE_INSTEAD,
                            style = MaterialTheme.typography.bodyMedium,
                            color = colors.ink,
                        )
                    }
                }
            }
        }
    }
}
