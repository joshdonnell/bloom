import Foundation

/// The app-owned inbox ports, or the address of an existing inbox.
///
/// One source for the whole app rather than one per project. The built-in server is the default;
/// the address setting is kept for a server already running elsewhere.
///
/// The keys are here rather than in the settings pane so that the pane's `@AppStorage` and the
/// `Mailbox` reading them at launch cannot disagree about a spelling.
public enum MailpitSettings {
    public static let enabledKey = "mailpit.enabled"
    public static let addressKey = "mailpit.address"
    public static let bundledKey = "mailpit.bundled"
    public static let usesBundledServerByDefault = true

    public struct Ports: Equatable, Sendable {
        public let smtp: Int
        public let api: Int

        public init(smtp: Int, api: Int) {
            self.smtp = smtp
            self.api = api
        }
    }

    /// The Dev app gets different ports, so it cannot claim the production app's listeners.
    /// An unbundled run is treated as development for the same reason.
    public static func bundledPorts(forBundleIdentifier identifier: String?) -> Ports {
        identifier == Store.primaryBundleIdentifier
            ? Ports(smtp: 1025, api: 8025)
            : Ports(smtp: 1026, api: 8026)
    }

    public static func bundledAddress(forBundleIdentifier identifier: String?) -> String {
        "http://127.0.0.1:\(bundledPorts(forBundleIdentifier: identifier).api)"
    }

    /// Off until somebody switches it on in Settings > Incoming mails. The bundled server should
    /// not open an SMTP port, or add a sidebar destination, without that choice.
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
