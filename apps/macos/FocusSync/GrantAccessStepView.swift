import SwiftUI

struct GrantAccessStepView: View {
    @Bindable var model: FocusHarnessModel

    private var notificationsDenied: Bool { model.notificationsDenied }
    private var focusDenied: Bool { model.focusAccess == .denied }

    var body: some View {
        Form {
            Section {
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
                LabeledContent {
                    PermissionStatusIcon(granted: model.focusAccess == .granted)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ProductCopy.focusStatusRowTitle)
                        Text(ProductCopy.focusStatusRowSubtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(ProductCopy.grantAccessTitle)
            } footer: {
                Text(footer)
                    .foregroundStyle(model.automationDenied || notificationsDenied || focusDenied ? .red : .secondary)
            }
            Section {
                HStack {
                    Spacer()
                    if model.automationDenied {
                        Button(ProductCopy.openAutomation, action: model.openAutomationSettings)
                            .buttonStyle(.borderedProminent)
                    } else if notificationsDenied {
                        Button(ProductCopy.openNotifications, action: model.openNotificationSettings)
                            .buttonStyle(.borderedProminent)
                    } else if focusDenied {
                        Button(ProductCopy.openFocusStatus, action: model.openFocusStatusSettings)
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
        if model.automationDenied { return ProductCopy.automationDenied }
        if notificationsDenied { return ProductCopy.notificationsDenied }
        if focusDenied { return ProductCopy.focusStatusDenied }
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
