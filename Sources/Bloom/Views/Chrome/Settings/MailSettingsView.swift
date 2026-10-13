import SwiftUI
import BloomCore

/// Settings > Mail: where Mailpit is, and whether Bloom shows it.
///
/// One address for the whole Mac, for the reason `MailpitSettings` gives. Off until it is switched
/// on here, which is the only place it can be: see `MailpitSettings.isOnByDefault`. Once it is on,
/// Mail appears in the sidebar even while Bloom is still looking for the server.
struct MailSettingsView: View {
    private var preferences = MailpitPreferences()

    private var mailbox: Mailbox { .shared }

    var body: some View {
        Form {
            Section {
                Toggle("Show Mail in the sidebar", isOn: preferences.$isEnabled)
                TextField("Address", text: preferences.$address, prompt: Text(MailpitSettings.defaultAddress))
                    .disabled(!preferences.isEnabled)
                    .autocorrectionDisabled()
            } header: {
                Text("Mailpit")
            } footer: {
                VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                    Text(status)
                    Text("This is Mailpit's web address. To send test mail, configure your app's SMTP server separately. Mailpit defaults to localhost:1025.")
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
