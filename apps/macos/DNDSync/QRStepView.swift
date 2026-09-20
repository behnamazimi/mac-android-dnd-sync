import AppKit
import SwiftUI

struct QRStepView: View {
    @Bindable var model: FocusHarnessModel

    /// Same hint copy as before, with the download CTA inlined as a real
    /// link instead of a separate footer button.
    private var hint: AttributedString {
        var text = AttributedString("\(ProductCopy.qrBody) ")
        text.foregroundColor = .secondary
        var link = AttributedString(ProductCopy.downloadAndroidApp)
        link.link = Distribution.githubReleases
        text.append(link)
        return text
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    // One waiting row, shown up top instead of duplicated
                    // above and below the QR. `qrMessage` already carries
                    // "Getting ready…" before APNs registers and "Waiting
                    // for your phone…" once the pair exists.
                    if !model.qrNeedsRetry {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(model.qrMessage ?? ProductCopy.waitingPhone)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let qrImage = model.qrImage {
                        Image(nsImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 162, height: 162)
                            .padding(9)
                            // Intentionally fixed white: a QR code must render
                            // on a guaranteed-light backing so phone cameras
                            // can scan it regardless of the app's appearance.
                            .background(Color.white)
                            .clipShape(.rect(cornerRadius: 10))
                            .accessibilityLabel("QR code to connect your phone")
                    }
                    // Not a real typeable numeric code — camera/QR scan is the
                    // only working pairing path today. This keeps the
                    // existing "copy the JSON payload" fallback, worded
                    // honestly as a copy action, not a code to type.
                    Button(ProductCopy.copyPairingCode, action: model.copyPairPayload)
                        .buttonStyle(.bordered)
                        .disabled(model.pairPayloadJSON.isEmpty)
                    if model.qrNeedsRetry {
                        Text(model.qrMessage ?? ProductCopy.qrBody)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                        Button(ProductCopy.tryAgain, action: model.retryCreatePair)
                            .buttonStyle(.borderedProminent)
                    } else {
                        // Not on the App Store yet — hidden during the retry
                        // error so a failed pair-create isn't crowded with an
                        // unrelated download.
                        Text(hint)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
        }
        .formStyle(.grouped)
    }
}
