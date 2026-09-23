import SwiftUI

struct HomeScreen: View {
    @Bindable var model: FocusHarnessModel
    @Environment(\.chromeActions) private var chrome
    @State private var showHelp = false

    private var hasError: Bool { model.productLastError != ProductCopy.emDash }

    private var statusSymbol: String {
        if model.showOffline { return "wifi.slash" }
        if hasError { return "exclamationmark.triangle.fill" }
        return "checkmark.circle.fill"
    }

    private var statusTint: Color {
        if model.showOffline { return .secondary }
        if hasError { return .orange }
        return .green
    }

    private var statusTitle: String {
        if model.showOffline { return ProductCopy.offlineTitle }
        if hasError { return model.productLastError }
        return ProductCopy.inSyncTitle
    }

    private var statusSubtitle: String {
        guard !model.showOffline, !hasError, LastSyncPresentation.hasSync(model.lastSyncUnixMs) else {
            return ProductCopy.neverSynced
        }
        let peer = LastSyncPresentation.peerLabel(model.peerDeviceName)
        return "Focus matches \(peer) · last synced \(relativeTime(model.lastSyncUnixMs))"
    }

    private func relativeTime(_ unixMs: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(unixMs) / 1000)
        return date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: statusSymbol)
                        .font(.title3)
                        .foregroundStyle(statusTint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusTitle)
                            .font(.headline)
                        Text(statusSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    // Image-only + submitScope: a Form Button titled "Settings"
                    // became the default action on QR → Home and opened
                    // Settings with the unpair confirmation.
                    Button(action: chrome.openSettings) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .submitScope()
                    .help(ProductCopy.settings)
                    .accessibilityLabel(ProductCopy.settings)
                }
                .padding(.vertical, 4)
            }
            Section(ProductCopy.pairing) {
                LabeledContent {
                    Text(LastSyncPresentation.pathLabel(viaLan: model.lastSyncViaLan))
                        .foregroundStyle(.secondary)
                } label: {
                    Label(LastSyncPresentation.peerLabel(model.peerDeviceName), systemImage: "iphone")
                }
            }
            if model.notificationsDenied {
                Section {
                    Button(ProductCopy.openNotifications, action: model.openNotificationSettings)
                }
            }
            Section(ProductCopy.recentActivity) {
                if model.recentActivity.isEmpty {
                    Text(ProductCopy.neverSynced)
                        .foregroundStyle(.secondary)
                } else {
                    // Periodic tick so "2 min ago" keeps advancing while Home stays open.
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        ForEach(model.recentActivity) { event in
                            LabeledContent {
                                Text(relativeTime(event.unixMs))
                                    .foregroundStyle(.secondary)
                            } label: {
                                Text(RecentActivity.line(on: event.on, sender: event.sender))
                            }
                        }
                    }
                }
            }
            if model.paired && (!model.onExists || !model.offExists || model.automationDenied) {
                Section {
                    if !model.onExists {
                        Button(ProductCopy.addOn, action: model.importOn)
                    }
                    if !model.offExists {
                        Button(ProductCopy.addOff, action: model.importOff)
                    }
                    if model.automationDenied {
                        Button(ProductCopy.openAutomation, action: model.openAutomationSettings)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            Button(ProductCopy.howDoesThisWork, action: { showHelp = true })
                .buttonStyle(.link)
                .font(.footnote)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
        }
        .overlay {
            if showHelp {
                DismissibleOverlay(onDismiss: { showHelp = false }, hugContent: true) {
                    HowThisWorksSheet(onClose: { showHelp = false })
                }
            }
        }
    }
}

private struct HowThisWorksSheet: View {
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetCloseHeader(close: onClose)
            VStack(alignment: .leading, spacing: 8) {
                Text(ProductCopy.howDoesThisWork)
                    .font(.headline)
                Text(ProductCopy.howThisWorksBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
    }
}
