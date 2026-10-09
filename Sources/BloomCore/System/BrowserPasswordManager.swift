import Foundation
import Security

/// 1Password in the browser pane, by loading the Safari extension the user already has.
///
/// **The extension is 1Password's own and nothing of it is copied here.** Since macOS 15.4 WebKit
/// can run a Safari web extension inside an app's own `WKWebView` (`WKWebExtensionController`), and
/// `WKWebExtension(appExtensionBundle:)` takes the very `.appex` Safari runs. 1Password ships that
/// appex inside "1Password for Safari", from the App Store, rather than inside 1Password.app, so
/// that is what has to be installed.
///
/// **It cannot reach the 1Password app, and that was measured rather than assumed.** In Safari the
/// extension talks to the app through `browser.runtime.sendNativeMessage`, which WebKit hands to
/// the appex's own handler through `NSExtension` (`WebExtensionContextAPIRuntimeCocoa.mm`). That
/// lookup returns nothing outside Safari, because finding a Safari web extension needs a private
/// entitlement Safari has and no third party app can. So the extension runs on its own: the
/// toolbar button opens 1Password's welcome page, and the account is signed in to there, with the
/// Secret Key, rather than unlocked by the app. Whether 1Password lets an account sign in this way
/// outside Safari has not been confirmed. `BrowserExtensionHost` has the detail.
///
/// The setting is off by default and says what it needs.
public enum BrowserPasswordManager {
    public static let settingKey = "browser.usesOnePassword"
    public static let isOnByDefault = false

    /// The extension point every Safari web extension registers under, which is what `pluginkit`
    /// is asked about.
    public static let extensionPoint = "com.apple.Safari.web-extension"

    /// One line of `pluginkit -m -v`: which appex, at what version, where on disk.
    public struct Installed: Equatable, Sendable {
        public let identifier: String
        public let version: String
        public let path: String

        public init(identifier: String, version: String, path: String) {
            self.identifier = identifier
            self.version = version
            self.path = path
        }
    }

    /// Every Safari web extension `pluginkit` reported.
    ///
    /// A line is an election mark, spaces, `identifier(version)`, then tab separated UUID,
    /// timestamp and path: `+    com.example.ext(1.2)\t4339EF...\t2026-10-02 00:06:10 +0000\t/Ap...`.
    /// The mark is `+`, `-`, `!`, `=` or a space, and none of them matters here: whether Safari
    /// has the extension switched on is Safari's business, and 1Password's own app is what decides
    /// whether a caller is answered. The path is taken as the last field rather than the fourth,
    /// so a pluginkit that adds a column in the middle still yields the right one.
    public static func installed(fromPluginKit output: String) -> [Installed] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 2,
                  let path = fields.last.map({ $0.trimmingCharacters(in: .whitespaces) }),
                  path.hasPrefix("/")
            else { return nil }

            let head = fields[0].drop { "+-!=? ".contains($0) }.trimmingCharacters(in: .whitespaces)
            guard !head.isEmpty else { return nil }
            guard head.hasSuffix(")"), let open = head.lastIndex(of: "(") else {
                return Installed(identifier: head, version: "", path: path)
            }
            let identifier = String(head[..<open])
            let version = String(head[head.index(after: open)..<head.index(before: head.endIndex)])
            guard !identifier.isEmpty else { return nil }
            return Installed(identifier: identifier, version: version, path: path)
        }
    }

    /// 1Password's appex out of everything installed, or nil.
    ///
    /// By identifier first, since that is what 1Password controls, and by the containing app's
    /// name as the fallback. `com.agilebits` is the prefix 1Password used before 1Password 8 and
    /// still uses on some bundles. An appex inside `/Applications` beats one anywhere else, so a
    /// copy sitting in a Downloads folder does not win over the installed one.
    ///
    /// The fallback reads the outermost `.app` in the path and nothing else. A substring test on
    /// the whole path would take any extension inside a folder called 1Password, and any app whose
    /// name merely starts with the word.
    public static func onePassword(in installed: [Installed]) -> Installed? {
        let matches = installed.filter(isOnePassword)
        return matches.first { $0.path.hasPrefix("/Applications/") } ?? matches.first
    }

    private static func isOnePassword(_ entry: Installed) -> Bool {
        let identifier = entry.identifier.lowercased()
        if identifier.hasPrefix("com.1password.") || identifier.hasPrefix("com.agilebits.") {
            return true
        }
        return isOnePasswordApp(containing: entry.path)
    }

    /// Whether the outermost app in `path` is 1Password's: named "1Password", or "1Password" and
    /// then a space, which is "1Password for Safari" and "1Password Beta".
    private static func isOnePasswordApp(containing path: String) -> Bool {
        guard let app = path.split(separator: "/").first(where: { $0.hasSuffix(".app") }) else {
            return false
        }
        let name = app.dropLast(".app".count)
        return name == "1Password" || name.hasPrefix("1Password ")
    }

    /// What asking `pluginkit` came to.
    ///
    /// **Not being able to ask is not the same as an answer of no**, and it was first reported as
    /// one: a pluginkit that failed came back as nil and Settings told somebody who had
    /// 1Password for Safari installed to go and install it from the App Store.
    public enum Lookup: Equatable, Sendable {
        case found(Installed)
        case notInstalled
        case unavailable(String)
    }

    /// What pluginkit's exit status and output say, without running it.
    public static func lookup(status: Int32, output: String, errors: String = "") -> Lookup {
        guard status == 0 else {
            let said = errors.trimmingCharacters(in: .whitespacesAndNewlines)
            return .unavailable(said.isEmpty ? "pluginkit exited with status \(status)" : said)
        }
        return onePassword(in: installed(fromPluginKit: output)).map(Lookup.found) ?? .notInstalled
    }

    /// Asks `pluginkit` where 1Password's Safari extension is.
    public static func locate() async -> Lookup {
        do {
            let result = try await Shell.run(
                "/usr/bin/pluginkit", ["-m", "-v", "-p", extensionPoint], timeout: .seconds(30)
            )
            return lookup(status: result.status, output: result.stdout, errors: result.stderr)
        } catch {
            return .unavailable(error.localizedDescription)
        }
    }

    /// What `browser.runtime.id` should say: Safari's own spelling, the bundle identifier with the
    /// team in brackets after it.
    ///
    /// WebKit's default is a fresh UUID per load, which an extension that stores anything against
    /// its own identifier would see change on every launch. Safari's form is stable and is what
    /// 1Password's code has only ever been run under. Without a team it is the bundle identifier
    /// alone, which is still stable.
    public static func runtimeIdentifier(bundleIdentifier: String, teamIdentifier: String?) -> String {
        guard let teamIdentifier, !teamIdentifier.isEmpty else { return bundleIdentifier }
        return "\(bundleIdentifier) (\(teamIdentifier))"
    }

    /// Where the extension's own pages live, fixed rather than WebKit's default.
    ///
    /// **The default is a fresh host on every load**, and the host is the origin of every page the
    /// extension draws, so everything 1Password keeps in its pages' local storage and IndexedDB,
    /// which is the account it was signed in to, belonged to an origin that was gone by the next
    /// launch. A tab left open on one of its pages would also come back to an address naming
    /// nothing. Any fixed host will do; this one is a UUID so it can never be a real site's.
    public static let extensionBaseURL = URL(string: "webkit-extension://3f7c9a2e-58b1-4d06-a1e4-6c2d90b7f514/")!

    /// Whether the extension may have this address opened as a Bloom tab.
    ///
    /// Its own pages, which is what 1Password opens for its welcome and sign in screens, and
    /// ordinary web addresses, which is a site it is about to fill. Not any other scheme: the
    /// gate a page's `window.open` goes through, `BrowserAddress.shows`, refuses every one of
    /// those for good reasons, and this door is only wider by the extension's own origin.
    public static func mayOpenTab(_ url: URL, extensionBase: URL = extensionBaseURL) -> Bool {
        BrowserAddress.shows(url) || isExtensionPage(url, extensionBase: extensionBase)
    }

    /// Whether this is one of the extension's own pages, which a web view can only show if it was
    /// made with the extension's configuration rather than a browser tab's. See
    /// `BrowserExtensionHost.configuration(forPageAt:)`.
    public static func isExtensionPage(_ url: URL, extensionBase: URL = extensionBaseURL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), let host = url.host()?.lowercased() else {
            return false
        }
        return scheme == extensionBase.scheme?.lowercased() && host == extensionBase.host()?.lowercased()
    }

    /// Why an agent may not drive browser `number` while it shows `address`, or nil when it may.
    ///
    /// **The extension's own pages are the password manager itself, not a site.** They are where
    /// the Secret Key is typed and, once signed in, where the vault is listed. Every other page a
    /// `browser_` tool can reach is one the reader opened on the web, which the head of
    /// `BrowserPaneCommand` argues for; these are not that, so no tool reads, types into or
    /// photographs one. `browser_read` still answers, because it reports the address and title a
    /// tab already shows in the strip and nothing out of the page.
    public static func agentRefusal(address: String, browser number: Int) -> String? {
        guard let url = URL(string: address), isExtensionPage(url) else { return nil }
        return "Browser \(number) is showing one of 1Password's own pages, which hold its sign in "
            + "and its vault. Bloom does not let an agent read, type into or photograph them."
    }

    /// The signing team of the bundle at `url`, read from its code signature, or nil.
    public static func teamIdentifier(ofBundleAt url: URL) -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code else {
            return nil
        }
        var information: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(code, flags, &information) == errSecSuccess,
              let dictionary = information as? [String: Any]
        else { return nil }
        return dictionary[kSecCodeInfoTeamIdentifier as String] as? String
    }
}
