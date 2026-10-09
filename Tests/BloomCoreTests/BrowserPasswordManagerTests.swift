import Foundation
import Testing
@testable import BloomCore

/// Finding 1Password's Safari extension in what `pluginkit` says, and naming it the way Safari does.
@Suite("Browser password manager")
struct BrowserPasswordManagerTests {
    /// The shape `pluginkit -m -v` prints, copied from this Mac with the paths changed.
    private static let output = """
    +    com.example.reader.extension(2.1)\t4339EFDB-8E4A-5264-A3C0-B908E02A0520\t2026-10-02 00:06:10 +0000\t/Applications/Reader.app/Contents/PlugIns/Reader Extension.appex
    -    com.1password.safari.extension(8.11.4)\tD73F4E4F-8EFC-53A1-B0E7-3CF9E0908856\t2026-10-02 00:06:09 +0000\t/Applications/1Password for Safari.app/Contents/PlugIns/1Password.appex

    """

    @Test("Each line gives the identifier, the version and the path")
    func parsesEachLine() throws {
        let installed = BrowserPasswordManager.installed(fromPluginKit: Self.output)
        try #require(installed.count == 2)
        #expect(installed[1] == BrowserPasswordManager.Installed(
            identifier: "com.1password.safari.extension",
            version: "8.11.4",
            path: "/Applications/1Password for Safari.app/Contents/PlugIns/1Password.appex"
        ))
    }

    @Test("A line with no version in brackets still names the extension")
    func aMissingVersionIsEmpty() {
        let installed = BrowserPasswordManager.installed(
            fromPluginKit: "     com.example.bare\tUUID\tdate\t/Applications/Bare.app/Contents/PlugIns/Bare.appex"
        )
        #expect(installed.map(\.identifier) == ["com.example.bare"])
        #expect(installed.first?.version == "")
    }

    @Test("Lines that are not extensions are skipped rather than guessed at")
    func noiseIsSkipped() {
        let installed = BrowserPasswordManager.installed(
            fromPluginKit: "match: no matches\n\n+    \tUUID\tdate\t/Applications/Nameless.appex\n"
        )
        #expect(installed.isEmpty)
    }

    @Test("1Password is picked out whatever its election mark says")
    func findsOnePassword() {
        let found = BrowserPasswordManager.onePassword(
            in: BrowserPasswordManager.installed(fromPluginKit: Self.output)
        )
        #expect(found?.identifier == "com.1password.safari.extension")
    }

    @Test("An identifier under the old company name counts, and so does the app's folder")
    func olderNamesCount() {
        let agilebits = BrowserPasswordManager.Installed(
            identifier: "com.agilebits.onepassword.safari", version: "", path: "/Applications/X.appex"
        )
        let byPath = BrowserPasswordManager.Installed(
            identifier: "com.example.other", version: "", path: "/Applications/1Password Beta.app/x.appex"
        )
        #expect(BrowserPasswordManager.onePassword(in: [agilebits]) == agilebits)
        #expect(BrowserPasswordManager.onePassword(in: [byPath]) == byPath)
    }

    @Test("The path fallback reads the containing app's name, not any folder or prefix")
    func thePathFallbackIsAnchoredToTheApp() {
        let inAFolder = BrowserPasswordManager.Installed(
            identifier: "com.example.helper", version: "", path: "/Applications/1Password/Helper.app/x.appex"
        )
        let lookalike = BrowserPasswordManager.Installed(
            identifier: "com.example.other", version: "", path: "/Applications/1PasswordSomething.app/x.appex"
        )
        let plain = BrowserPasswordManager.Installed(
            identifier: "com.example.other", version: "", path: "/Applications/1Password.app/x.appex"
        )
        #expect(BrowserPasswordManager.onePassword(in: [inAFolder]) == nil)
        #expect(BrowserPasswordManager.onePassword(in: [lookalike]) == nil)
        #expect(BrowserPasswordManager.onePassword(in: [plain]) == plain)
    }

    @Test("pluginkit failing is not the same answer as 1Password missing")
    func aFailedLookupIsNotAMissingExtension() {
        #expect(BrowserPasswordManager.lookup(status: 1, output: "", errors: "no plugin database\n")
            == .unavailable("no plugin database"))
        #expect(BrowserPasswordManager.lookup(status: 70, output: "") == .unavailable("pluginkit exited with status 70"))
        #expect(BrowserPasswordManager.lookup(status: 0, output: "") == .notInstalled)
        let found = BrowserPasswordManager.lookup(status: 0, output: Self.output)
        #expect(found == .found(BrowserPasswordManager.Installed(
            identifier: "com.1password.safari.extension",
            version: "8.11.4",
            path: "/Applications/1Password for Safari.app/Contents/PlugIns/1Password.appex"
        )))
    }

    @Test("Another password manager is not mistaken for 1Password")
    func otherManagersAreIgnored() {
        let nordPass = BrowserPasswordManager.Installed(
            identifier: "com.nordpass.macos.safari", version: "5.0", path: "/Applications/NordPass.app/x.appex"
        )
        #expect(BrowserPasswordManager.onePassword(in: [nordPass]) == nil)
    }

    @Test("The copy in Applications wins over one anywhere else")
    func applicationsWins() {
        let downloaded = BrowserPasswordManager.Installed(
            identifier: "com.1password.safari.extension", version: "8.0",
            path: "/Users/someone/Downloads/1Password for Safari.app/x.appex"
        )
        let installed = BrowserPasswordManager.Installed(
            identifier: "com.1password.safari.extension", version: "8.1",
            path: "/Applications/1Password for Safari.app/x.appex"
        )
        #expect(BrowserPasswordManager.onePassword(in: [downloaded, installed]) == installed)
    }

    @Test("The runtime identifier is Safari's spelling, and the bundle identifier without a team")
    func runtimeIdentifier() {
        #expect(BrowserPasswordManager.runtimeIdentifier(
            bundleIdentifier: "com.1password.safari.extension", teamIdentifier: "2BUA8C4S2C"
        ) == "com.1password.safari.extension (2BUA8C4S2C)")
        #expect(BrowserPasswordManager.runtimeIdentifier(
            bundleIdentifier: "com.example.ext", teamIdentifier: nil
        ) == "com.example.ext")
        #expect(BrowserPasswordManager.runtimeIdentifier(
            bundleIdentifier: "com.example.ext", teamIdentifier: ""
        ) == "com.example.ext")
    }

    @Test("The extension may open its own pages and web addresses, and nothing else")
    func whatTheExtensionMayOpen() throws {
        let base = BrowserPasswordManager.extensionBaseURL
        let welcome = try #require(URL(string: base.absoluteString + "app/app.html#/page/welcome?language=en"))
        #expect(BrowserPasswordManager.mayOpenTab(welcome))
        #expect(BrowserPasswordManager.isExtensionPage(welcome))
        #expect(!BrowserPasswordManager.isExtensionPage(try #require(URL(string: "https://my.1password.com/"))))
        #expect(BrowserPasswordManager.mayOpenTab(try #require(URL(string: "https://my.1password.com/signin"))))

        let otherExtension = try #require(URL(string: "webkit-extension://somebody-else/app.html"))
        #expect(!BrowserPasswordManager.mayOpenTab(otherExtension))
        #expect(!BrowserPasswordManager.mayOpenTab(try #require(URL(string: "file:///etc/hosts"))))
        #expect(!BrowserPasswordManager.mayOpenTab(try #require(URL(string: "javascript:alert(1)"))))
    }

    @Test("An agent is refused the extension's own pages and nothing else")
    func agentsAreKeptOffTheExtensionsPages() {
        let welcome = BrowserPasswordManager.extensionBaseURL.absoluteString + "app/app.html#/page/welcome"
        let refusal = BrowserPasswordManager.agentRefusal(address: welcome, browser: 2)
        #expect(refusal?.hasPrefix("Browser 2 is showing one of 1Password's own pages") == true)
        #expect(BrowserPasswordManager.agentRefusal(address: "https://my.1password.com/", browser: 1) == nil)
        #expect(BrowserPasswordManager.agentRefusal(address: "http://localhost:3000", browser: 1) == nil)
        #expect(BrowserPasswordManager.agentRefusal(address: "", browser: 1) == nil)
    }

    @Test("A failure says why, and a loaded extension names its version when it has one")
    func footnotes() {
        typealias Status = BrowserPasswordManager.Status
        #expect(Status.failed("bad manifest").footnote(isOn: true).hasSuffix("bad manifest"))
        #expect(Status.ready(version: "8.11").footnote(isOn: true).hasPrefix("1Password 8.11 is loaded."))
        #expect(Status.ready(version: "").footnote(isOn: true).hasPrefix("1Password is loaded."))
        #expect(!Status.cannotLook("timed out").footnote(isOn: true).contains("App Store"))
    }

    @Test("Switched off, the line says what switching on does, permissions included")
    func theOffLineIsInformedConsent() {
        let line = BrowserPasswordManager.Status.ready(version: "8.11").footnote(isOn: false)
        #expect(line == BrowserPasswordManager.Status.off.footnote(isOn: true))
        #expect(line.contains("every permission it asks for, on every site"))
    }

    // MARK: - The switch

    @Test("Switching on looks, and a found extension is loaded and reported ready")
    func aSwitchThatLoads() {
        var lifecycle = BrowserPasswordManager.Switch()
        #expect(lifecycle.needsStart(isOn: true))
        #expect(!lifecycle.needsStart(isOn: false))

        let attempt = lifecycle.turnOn()
        #expect(lifecycle.status == .looking)
        #expect(!lifecycle.needsStart(isOn: true))

        let installed = BrowserPasswordManager.Installed(identifier: "com.1password.safari.extension", version: "8", path: "/x")
        #expect(lifecycle.looked(.found(installed), attempt: attempt) == installed)
        #expect(lifecycle.status == .looking)

        let accepted = lifecycle.loaded(version: "8.12", attempt: attempt)
        #expect(accepted)
        #expect(lifecycle.status == .ready(version: "8.12"))
    }

    @Test("Nothing installed and pluginkit unavailable end in different states")
    func aSwitchThatFindsNothing() {
        var missing = BrowserPasswordManager.Switch()
        let first = missing.turnOn()
        #expect(missing.looked(.notInstalled, attempt: first) == nil)
        #expect(missing.status == .notInstalled)
        #expect(!missing.needsStart(isOn: true))

        var unavailable = BrowserPasswordManager.Switch()
        let second = unavailable.turnOn()
        #expect(unavailable.looked(.unavailable("timed out"), attempt: second) == nil)
        #expect(unavailable.status == .cannotLook("timed out"))
    }

    @Test("A load that fails after the switch moved on cannot overwrite the newer attempt")
    func staleAnswersAreDropped() {
        var lifecycle = BrowserPasswordManager.Switch()
        let first = lifecycle.turnOn()
        lifecycle.turnOff()
        let second = lifecycle.turnOn()

        lifecycle.failed("the manifest went away", attempt: first)
        #expect(lifecycle.status == .looking)
        let stale = lifecycle.loaded(version: "8", attempt: first)
        #expect(!stale)
        #expect(lifecycle.status == .looking)

        lifecycle.turnOff()
        lifecycle.failed("too late", attempt: second)
        #expect(lifecycle.status == .off)
    }

    // MARK: - The host's decisions

    @Test("The button is named by the extension, or by 1Password when it names nothing")
    func actionLabels() {
        #expect(BrowserPasswordManager.actionLabel("") == "1Password")
        #expect(BrowserPasswordManager.actionLabel("1Password: locked") == "1Password: locked")
    }

    @Test("A new tab opens beside the active one, else the newest, else nowhere")
    func openers() {
        #expect(BrowserPasswordManager.opener(active: "b", open: ["a", "b", "c"]) == "b")
        #expect(BrowserPasswordManager.opener(active: nil, open: ["a", "b", "c"]) == "c")
        #expect(BrowserPasswordManager.opener(active: nil as String?, open: []) == nil)
    }

    @Test("The popup hangs from the button, else the page, else is refused")
    func popupAnchors() {
        typealias Anchor = BrowserPasswordManager.PopupAnchor
        #expect(BrowserPasswordManager.popupAnchor(buttonIsInWindow: true, pageIsInWindow: true) == Anchor.button)
        #expect(BrowserPasswordManager.popupAnchor(buttonIsInWindow: false, pageIsInWindow: true) == Anchor.pageTop)
        #expect(BrowserPasswordManager.popupAnchor(buttonIsInWindow: false, pageIsInWindow: false) == Anchor.nowhere)
    }

    @Test("A page waiting on the extension says whether it is waiting or switched off")
    func waitingPages() {
        #expect(BrowserPasswordManager.waitingPage(isOn: true).title == "Waiting for 1Password")
        #expect(BrowserPasswordManager.waitingPage(isOn: false).title == "1Password is switched off")
    }
}
