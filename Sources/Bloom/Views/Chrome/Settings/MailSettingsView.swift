import SwiftUI
import BloomCore

/// Settings > Incoming mails: an app-owned inbox by default, or an existing server by URL.
struct MailSettingsView: View {
    private var preferences = MailpitPreferences()

    private var mailbox: Mailbox { .shared }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: preferences.$isEnabled) {
                    Text("Enable incoming mails")
                    Text(preferences.usesBundledServer
                         ? "Bloom receives test emails while it is open. No separate installation is needed."
                         : "Show messages from your existing test inbox.")
                }
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
                Text(status).settingsFootnote()
            }

            Section {
                if preferences.usesBundledServer {
                    SettingsRow("SMTP host") {
                        Text("127.0.0.1").font(Typo.codeSmall).textSelection(.enabled)
                    }
                    SettingsRow("SMTP port") {
                        Text(String(smtpPort)).font(Typo.codeSmall).textSelection(.enabled)
                    }
                    SettingsRow("Encryption") { Text("None") }
                    SettingsRow("Authentication") { Text("None") }
                } else {
                    Text("Point your app's SMTP connection at your existing test server. The inbox URL above is for Bloom to read its messages.")
                        .font(Typo.body)
                }
                MailSetupButton(usesBundledServer: preferences.usesBundledServer)
            } header: {
                Text("Send test mail from your app")
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
