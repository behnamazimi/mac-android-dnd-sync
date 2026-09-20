import SwiftUI

/// Floor for the main window's *content* area (not the frame). Must stay in
/// sync with `NSWindow.contentMinSize` in `ProductChrome` — `minSize` includes
/// the title bar, so using the same numbers there lets the last lines of
/// Home / Welcome clip when the window is shortened.
enum ProductWindowMetrics {
    static let minWidth: CGFloat = 480
    static let minHeight: CGFloat = 420
}

struct ProductRootView: View {
    @Bindable var model: FocusHarnessModel

    var body: some View {
        Group {
            switch model.destination {
            case .welcome:
                WelcomeStepView(model: model)
            case .automation:
                GrantAccessStepView(model: model)
            case .shortcuts:
                ShortcutsStepView(model: model)
            case .loginItem:
                LoginItemStepView(model: model)
            case .qr:
                QRStepView(model: model)
            case .status:
                HomeScreen(model: model)
            }
        }
        // Reset identity on each step so a Form default-button click cannot
        // leak from QR onto Home's Settings control.
        .id(model.destination)
        .frame(minWidth: ProductWindowMetrics.minWidth, minHeight: ProductWindowMetrics.minHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            if model.showOffline {
                OfflineToast()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .onChange(of: model.destination, initial: true) { _, dest in
            model.handleDestination(dest)
        }
    }
}

private struct OfflineToast: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ProductCopy.offlineTitle)
                .font(.body)
                .foregroundStyle(.primary)
            Text(ProductCopy.offlineBody)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
