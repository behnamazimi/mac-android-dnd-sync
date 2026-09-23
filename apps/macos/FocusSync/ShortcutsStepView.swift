import SwiftUI

struct ShortcutsStepView: View {
    @Bindable var model: FocusHarnessModel

    var body: some View {
        Form {
            Section {
                ShortcutStatusRow(
                    label: ProductCopy.shortcutRowOn,
                    added: model.onExists,
                    addTitle: ProductCopy.addOn,
                    action: model.importOn
                )
                ShortcutStatusRow(
                    label: ProductCopy.shortcutRowOff,
                    added: model.offExists,
                    addTitle: ProductCopy.addOff,
                    action: model.importOff
                )
            } header: {
                Text(ProductCopy.shortcutsTitle)
            } footer: {
                Text(footer)
                    .foregroundStyle(footerIsError ? .red : .secondary)
            }
            Section {
                HStack {
                    Button(retryTitle, action: model.recheckShortcuts)
                        .disabled(model.provingShortcuts)
                    Spacer()
                    if model.automationDenied {
                        Button(ProductCopy.openAutomation, action: model.openAutomationSettings)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var footer: String {
        if model.automationDenied { return ProductCopy.automationDenied }
        if let error = model.shortcutStepError, !error.isEmpty { return error }
        if model.onExists && model.offExists && !model.shortcutsProven {
            return ProductCopy.shortcutsProveBody
        }
        return ProductCopy.shortcutsBody
    }

    private var footerIsError: Bool {
        model.automationDenied || (model.shortcutStepError?.isEmpty == false)
    }

    private var retryTitle: String {
        if model.onExists && model.offExists && !model.shortcutsProven {
            return ProductCopy.tryAgain
        }
        return ProductCopy.checkAgain
    }
}

private struct ShortcutStatusRow: View {
    let label: String
    let added: Bool
    let addTitle: String
    let action: () -> Void

    var body: some View {
        LabeledContent(label) {
            if added {
                Label(ProductCopy.shortcutAdded, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(addTitle, action: action)
            }
        }
    }
}
