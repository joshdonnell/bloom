import Foundation

/// Where Bloom looks for Mailpit, and whether it looks at all.
///
/// One address for the whole Mac rather than one per project. The common setup is a single Mailpit
/// that Herd, DBngin or `brew services` keeps running on `localhost:8025`, and every project on the
/// machine sends to it, so the default address is right for most people once the switch is on.
///
/// The keys are here rather than in the settings pane so that the pane's `@AppStorage` and the
/// `Mailbox` reading them at launch cannot disagree about a spelling.
public enum MailpitSettings {
    public static let enabledKey = "mailpit.enabled"
    public static let addressKey = "mailpit.address"

    /// Off until somebody switches it on in Settings > Incoming mails. On by default, Bloom would
    /// knock on a port on every Mac every thirty seconds, for a tool most people do not have, and
    /// Mail would turn up unasked in the sidebar.
    public static let isOnByDefault = false
    public static let defaultAddress = "http://localhost:8025"

    /// The base every request is built on, from whatever was typed into Settings.
    ///
    /// Lenient about what people actually type. `localhost:8025` has no scheme, and Foundation
    /// reads the host as the scheme and the port as a path, so a bare host gets `http://` in front
    /// of it. A trailing slash is dropped so that `appending(path:)` gives one slash rather than
    /// two, and a path is kept, because Mailpit can be served under a web root such as `/mailpit`.
    ///
    /// Nil for anything that does not come out as an http or https address with a host, which is
    /// what the pane reads as "not an address" rather than "Mailpit is not running".
    public static func base(from typed: String) -> URL? {
        var text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "http://" + text }
        while text.hasSuffix("/") { text.removeLast() }
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host(), !host.isEmpty
        else { return nil }
        return url
    }
}
