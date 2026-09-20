import SwiftUI

struct WelcomeStepView: View {
    @Bindable var model: FocusHarnessModel

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Image("BrandLogo")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 48, height: 48)
                        .accessibilityHidden(true)
                    Text(ProductCopy.welcomeTitle)
                        .font(.title2.bold())
                    Text(ProductCopy.welcomeBody)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            Section {
                Button(ProductCopy.getStarted, action: model.dismissWelcome)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            Text(ProductCopy.welcomeCaption)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
        }
    }
}
