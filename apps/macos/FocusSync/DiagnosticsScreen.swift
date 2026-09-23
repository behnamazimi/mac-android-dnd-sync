import SwiftUI

/// The Diagnostics window's root view. Only ever constructed from
/// `ProductChrome.showDiagnostics()`, which only exists in `#if DEBUG`
/// builds — never reachable in Release (AGENTS.md: on/off test buttons and
/// this screen must never ship in release builds).
struct DiagnosticsScreen: View {
    @Bindable var model: FocusHarnessModel
    @State private var confirmUnpair = false

    private var logLines: [String] {
        [
            model.pairStatusText,
            model.apnsReadyText,
            "Automation denied: \(model.automationDenied ? "yes" : "no")",
            "On shortcut: \(model.onExists ? "yes" : "no")",
            "Off shortcut: \(model.offExists ? "yes" : "no")",
            "Shortcuts proven: \(model.shortcutsProven ? "yes" : "no")",
            "Login item: \(model.loginItemEnabled ? "enabled" : "off")",
            LocalCommandServer.diagnosticsCurlHint,
            "LAN advertising: \(model.lanAdvertising ? "yes" : "no")",
            "LAN browsing: \(model.lanBrowsing ? "yes" : "no")",
            "LAN connected: \(model.lanConnected ? "yes" : "no")",
            model.lastInboundText,
            model.lastLanErrorText,
            model.lastRegisterText,
            model.lastEnvelopePostText,
            model.lastCloudErrorText,
            model.focusStatusText,
            "Focus status access: \(model.focusAccess)",
            model.lastRunText,
            model.lastRemoteCommandText,
            model.lastApnsText,
        ]
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Button("Force ON", action: model.turnOn)
                    Button("Force OFF", action: model.turnOff)
                    Spacer()
                    Text("LAN: \(model.lanConnected ? "connected" : "idle") · Cloud: \(model.apnsTokenHex.isEmpty ? "idle" : "ready")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(ProductCopy.diagnostics)
            } footer: {
                Text("Debug build only · never shown in release")
                    .foregroundStyle(.orange)
            }
            Section("Log") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(logLines.indices, id: \.self) { index in
                            Text(logLines[index])
                                .font(.caption.monospaced())
                                .foregroundStyle(logLineColor(logLines[index]))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                .frame(minHeight: 220)
                .background(Color.black)
                .clipShape(.rect(cornerRadius: 6))
            }
            Section {
                LabeledContent("Device ID", value: model.pairIdText.isEmpty ? ProductCopy.emDash : LastSyncPresentation.truncatedPairId(model.pairIdText))
                Button(ProductCopy.unpair, role: .destructive, action: { confirmUnpair = true })
            }
        }
        .formStyle(.grouped)
        .alert(
            ProductCopy.unpairConfirmTitle,
            isPresented: $confirmUnpair
        ) {
            Button(ProductCopy.unpair, role: .destructive, action: { model.rePair() })
            Button(ProductCopy.cancel, role: .cancel) {}
        } message: {
            Text(ProductCopy.unpairConfirmBody)
        }
    }

    private func logLineColor(_ line: String) -> Color {
        let lower = line.lowercased()
        if lower.contains("error:") && !lower.hasSuffix("—") {
            return Color(red: 240 / 255, green: 180 / 255, blue: 41 / 255)
        }
        if lower.contains("fallback") || lower.contains("denied: yes") {
            return Color(red: 240 / 255, green: 180 / 255, blue: 41 / 255)
        }
        if lower.contains(": yes") || lower.contains("ok") || lower.contains("registered")
            || lower.contains("connected") || lower.contains("succeeded") || lower.contains("sent") {
            return Color(red: 143 / 255, green: 209 / 255, blue: 158 / 255)
        }
        return Color(red: 200 / 255, green: 200 / 255, blue: 204 / 255)
    }
}
