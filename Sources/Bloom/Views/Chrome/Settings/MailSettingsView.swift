import SwiftUI
import BloomCore

/// Settings > Incoming mails: where the test inbox is, and whether Bloom shows it.
///
/// One address for the whole Mac, for the reason `MailpitSettings` gives. Off until it is switched
/// on here, which is the only place it can be: see `MailpitSettings.isOnByDefault`. Once it is on,
/// Incoming mails appears in the sidebar footer while Bloom looks for the server.
struct MailSettingsView: View {
    private var preferences = MailpitPreferences()

    private var mailbox: Mailbox { .shared }

    var body: some View {
        Form {
            Section {
                Toggle("Show incoming mails in the sidebar", isOn: preferences.$isEnabled)
                TextField("Inbox URL", text: preferences.$address, prompt: Text(MailpitSettings.defaultAddress))
                    .disabled(!preferences.isEnabled)
                    .autocorrectionDisabled()
            } header: {
                Text("Incoming mails")
            } footer: {
                VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                    Text(status)
                    Text("Use the web address of your local test inbox. Configure your app's SMTP address separately (commonly localhost:1025).")
                }
                .settingsFootnote()
            }
        }
        .settingsForm()
    }

    private var status: String {
        mailbox.statusLine(isEnabled: preferences.isEnabled, address: preferences.address)
    }
}
