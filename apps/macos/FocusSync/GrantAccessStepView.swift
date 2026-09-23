import SwiftUI

struct GrantAccessStepView: View {
    @Bindable var model: FocusHarnessModel

    private var shortcutsGranted: Bool { model.probedAutomation && !model.automationDenied }
    private var automationDenied: Bool { model.automationDenied && model.probedAutomation }
    private var notificationsDenied: Bool { model.notificationsDenied }

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    PermissionStatusIcon(granted: shortcutsGranted)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ProductCopy.automationRowTitle)
                        Text(ProductCopy.automationRowSubtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent {
                    PermissionStatusIcon(granted: model.notificationsGranted)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ProductCopy.notificationsRowTitle)
                        Text(ProductCopy.notificationsRowSubtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(ProductCopy.grantAccessTitle)
            } footer: {
                Text(footer)
                    .foregroundStyle(automationDenied || notificationsDenied ? .red : .secondary)
            }
            Section {
                HStack {
                    Spacer()
                    if automationDenied {
                        Button(ProductCopy.openAutomation, action: model.openAutomationSettings)
                            .buttonStyle(.borderedProminent)
                    } else if notificationsDenied {
                        Button(ProductCopy.openNotifications, action: model.openNotificationSettings)
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button(ProductCopy.continueLabel, action: model.requestGrantAccessPermissions)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var footer: String {
        if automationDenied { return ProductCopy.automationDenied }
        if notificationsDenied { return ProductCopy.notificationsDenied }
        return ProductCopy.grantAccessBody
    }
}

/// A green checkmark / plain circle, matching how Settings' Pairing and
/// Advanced rows show trailing state (`Label`/`LabeledContent`, system
/// colors only) rather than a custom badge.
private struct PermissionStatusIcon: View {
    let granted: Bool

    var body: some View {
        Image(systemName: granted ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(granted ? Color.green : Color.secondary)
            .accessibilityLabel(granted ? ProductCopy.granted : ProductCopy.notGranted)
    }
}
