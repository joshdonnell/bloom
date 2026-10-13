import SwiftUI
import BloomCore

/// Settings > Mail: where Mailpit is, and whether Bloom shows it.
///
/// One address for the whole Mac, for the reason `MailpitSettings` gives. Off until it is switched
/// on here, which is the only place it can be: see `MailpitSettings.isOnByDefault`. Once it is on,
/// the inspector's Mail tab appears the first time Mailpit answers at the address.
struct MailSettingsView: View {
    private var preferences = MailpitPreferences()

    private var mailbox: Mailbox { .shared }

    var body: some View {
        Form {
            Section {
                Toggle("Show Mailpit's mail in the inspector", isOn: preferences.$isEnabled)
                TextField("Address", text: preferences.$address, prompt: Text(MailpitSettings.defaultAddress))
                    .disabled(!preferences.isEnabled)
                    .autocorrectionDisabled()
            } header: {
                Text("Mailpit")
            } footer: {
                Text(status)
                    .settingsFootnote()
            }
        }
        .settingsForm()
    }

    private var status: String {
        mailbox.statusLine(isEnabled: preferences.isEnabled, address: preferences.address)
    }
}
