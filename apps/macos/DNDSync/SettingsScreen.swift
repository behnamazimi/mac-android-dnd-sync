import AppKit
import SwiftUI

/// Settings as an overlay on the main window (see `ProductChrome.showSettings()`),
/// not a step of `ProductRootView`'s wizard switch. The style/tone every
/// other product screen matches.
struct SettingsScreen: View {
    @Bindable var model: FocusHarnessModel
    @Environment(\.chromeActions) private var chrome
    @State private var confirmUnpair = false

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(ProductCopy.appName) \(version) (Build \(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetCloseHeader(title: ProductCopy.settings, close: chrome.closeSettings)
            Form {
                Section(ProductCopy.pairing) {
                    if model.paired {
                        LabeledContent {
                            Text(LastSyncPresentation.pathLabel(viaLan: model.lanConnected))
                                .foregroundStyle(.secondary)
                        } label: {
                            Label(LastSyncPresentation.peerLabel(model.peerDeviceName), systemImage: "iphone")
                        }
                        HStack {
                            Button(ProductCopy.rePair, action: {
                                model.rePair()
                                chrome.closeSettings()
                            })
                            Spacer()
                            Button(ProductCopy.unpair, role: .destructive, action: { confirmUnpair = true })
                        }
                    } else {
                        Text(ProductCopy.notPaired)
                            .foregroundStyle(.secondary)
                    }
                }
                Section(ProductCopy.general) {
                    Toggle(ProductCopy.openAtLogin, isOn: Binding(
                        get: { model.loginItemEnabled },
                        set: { newValue in
                            if newValue {
                                model.enableLoginItem()
                            } else {
                                model.disableLoginItem()
                            }
                        }
                    ))
                    if let loginItemError = model.loginItemError {
                        Text(loginItemError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Toggle(ProductCopy.notifyIfSyncFails, isOn: $model.notifyOnSyncFailure)
                }
                Section(ProductCopy.about) {
                    HStack {
                        Text(ProductCopy.downloadAndroidApp)
                        Spacer()
                        Button(ProductCopy.openEllipsis) {
                            NSWorkspace.shared.open(Distribution.githubReleases)
                        }
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ProductCopy.seeSourceOnGitHub)
                            Text(ProductCopy.starIfItHelps)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(ProductCopy.openEllipsis) {
                            NSWorkspace.shared.open(Distribution.githubRepo)
                        }
                    }
                }
                #if DEBUG
                Section(ProductCopy.advanced) {
                    HStack {
                        Text(ProductCopy.diagnostics)
                        Spacer()
                        Button(ProductCopy.openEllipsis, action: chrome.openDiagnostics)
                    }
                }
                #endif
                Section {
                    Text(versionText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 12, trailing: 20))
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 0, for: .scrollContent)
        }
        .alert(
            ProductCopy.unpairConfirmTitle,
            isPresented: $confirmUnpair
        ) {
            Button(ProductCopy.unpair, role: .destructive, action: {
                model.rePair()
                chrome.closeSettings()
            })
            Button(ProductCopy.cancel, role: .cancel) {}
        } message: {
            Text(ProductCopy.unpairConfirmBody)
        }
        .frame(width: 420)
        .onExitCommand {
            // Nested unpair alert owns Escape until it's dismissed.
            if !confirmUnpair {
                chrome.closeSettings()
            }
        }
    }
}
