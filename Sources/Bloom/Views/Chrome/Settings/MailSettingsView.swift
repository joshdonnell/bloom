import SwiftUI
import BloomCore

/// Settings > Incoming mails: an app-owned inbox by default, or an existing server by URL.
struct MailSettingsView: View {
    private var preferences = MailpitPreferences()

    private var mailbox: Mailbox { .shared }

    var body: some View {
        Form {
            Section {
                Toggle("Enable incoming mails", isOn: preferences.$isEnabled)
                Picker("Inbox", selection: preferences.$usesBundledServer) {
                    Text("Built in").tag(true)
                    Text("Existing server").tag(false)
                }
                .disabled(!preferences.isEnabled)
                if !preferences.usesBundledServer {
                    TextField("Inbox URL", text: preferences.$address, prompt: Text(MailpitSettings.defaultAddress))
                        .disabled(!preferences.isEnabled)
                        .autocorrectionDisabled()
                }
            } header: {
                Text("Incoming mails")
            } footer: {
                VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                    Text(status)
                    if preferences.usesBundledServer {
                        Text("Set your app's SMTP host to 127.0.0.1 and port to \(smtpPort). Use no encryption or authentication.")
                    } else {
                        Text("Bloom connects to the inbox at this URL. Configure your app's SMTP address separately.")
                    }
                }
                .settingsFootnote()
            }
        }
        .settingsForm()
    }

    private var status: String {
        mailbox.statusLine(
            isEnabled: preferences.isEnabled,
            usesBundledServer: preferences.usesBundledServer,
            address: preferences.address
        )
    }

    private var smtpPort: Int {
        MailpitSettings.bundledPorts(forBundleIdentifier: Bundle.main.bundleIdentifier).smtp
    }
}
