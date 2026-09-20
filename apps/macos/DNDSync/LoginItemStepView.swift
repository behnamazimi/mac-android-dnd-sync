import SwiftUI

struct LoginItemStepView: View {
    @Bindable var model: FocusHarnessModel

    var body: some View {
        Form {
            Section {
                EmptyView()
            } header: {
                Text(ProductCopy.loginTitle)
            } footer: {
                Text(model.loginItemError ?? ProductCopy.loginBody)
                    .foregroundStyle(model.loginItemError != nil ? .red : .secondary)
            }
            Section {
                HStack {
                    Button(ProductCopy.skipForNow, action: model.skipLoginItem)
                    Spacer()
                    Button(ProductCopy.openAtLogin, action: model.enableLoginItem)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
    }
}
