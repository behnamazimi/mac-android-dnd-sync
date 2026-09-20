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
                Text(model.shortcutStepError ?? ProductCopy.shortcutsBody)
                    .foregroundStyle(model.shortcutStepError != nil ? .red : .secondary)
            }
            Section {
                HStack {
                    Button(ProductCopy.checkAgain, action: { model.probeShortcuts() })
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
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
