import SwiftUI
import BloomCore

/// Settings > Mail: where Mailpit is, and whether Bloom shows it.
///
/// One address for the whole Mac, for the reason `MailpitSettings` gives. Off until it is switched
/// on here, which is the only place it can be: see `MailpitSettings.isOnByDefault`. Once it is on,
/// the inspector's Mail tab appears the first time Mailpit answers at the address.
struct MailSettingsView: View {
    @AppStorage(MailpitSettings.enabledKey) private var isEnabled = MailpitSettings.isOnByDefault
    @AppStorage(MailpitSettings.addressKey) private var address = MailpitSettings.defaultAddress

    private var mailbox: Mailbox { .shared }

    var body: some View {
        Form {
            Section {
                Toggle("Show Mailpit's mail in the inspector", isOn: $isEnabled)
                TextField("Address", text: $address, prompt: Text(MailpitSettings.defaultAddress))
                    .disabled(!isEnabled)
                    .autocorrectionDisabled()
            } header: {
                Text("Mailpit")
            } footer: {
                Text(status)
                    .settingsFootnote()
            }
        }
        .settingsForm()
        .onChange(of: isEnabled) { _, _ in mailbox.settingsChanged() }
        .onChange(of: address) { _, _ in mailbox.settingsChanged() }
    }

    private var status: String {
        mailbox.statusLine(isEnabled: isEnabled, address: address)
    }
}
