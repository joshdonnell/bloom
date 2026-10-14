import SwiftUI
import BloomCore

/// The two Mailpit settings, as a view reads and writes them.
///
/// One declaration of the pair of `@AppStorage` lines, so the keys and defaults are spelled once
/// for every view that edits them, which today is Settings > Incoming mails. Nothing here tells
/// `Mailbox` they changed: it listens for that itself.
struct MailpitPreferences: DynamicProperty {
    @AppStorage(MailpitSettings.enabledKey) var isEnabled = MailpitSettings.isOnByDefault
    @AppStorage(MailpitSettings.addressKey) var address = MailpitSettings.defaultAddress
}
