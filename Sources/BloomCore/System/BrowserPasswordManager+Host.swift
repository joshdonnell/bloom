import Foundation

/// The small decisions `BrowserExtensionHost` takes on the extension's behalf. Here rather than
/// in the host because the host holds WebKit and lives in the app target, where nothing can test
/// it, and each of these has a wrong answer that would be invisible until a reader hit it.
extension BrowserPasswordManager {
    /// What the toolbar button is called. The extension's own label, or its name when it has set
    /// none, because a button with no name is one VoiceOver reads as "button".
    public static func actionLabel(_ label: String) -> String {
        label.isEmpty ? "1Password" : label
    }

    /// Which open tab a new tab the extension asked for opens beside.
    ///
    /// The active one, because that is the workspace the reader is in. Failing that the newest,
    /// because a tab must be named for the new one to land anywhere at all, and nil means the
    /// extension is told no tab could be opened rather than being handed nothing.
    public static func opener<Tab>(active: Tab?, open: [Tab]) -> Tab? {
        active ?? open.last
    }

    /// Where the extension's popup is drawn from.
    public enum PopupAnchor: Equatable, Sendable {
        /// Under the tab's toolbar button, which is where the reader pressed.
        case button
        /// From the top of the page, for a popup the extension opened by itself on a tab whose
        /// button is not on screen.
        case pageTop
        /// Nowhere, and the extension has to be told so: reporting success with nothing shown
        /// leaves it believing the popup is up.
        case nowhere
    }

    public static func popupAnchor(buttonIsInWindow: Bool, pageIsInWindow: Bool) -> PopupAnchor {
        if buttonIsInWindow { return .button }
        if pageIsInWindow { return .pageTop }
        return .nowhere
    }

    /// What a tab showing one of 1Password's own pages says while it cannot show it, because the
    /// extension that serves the page is not loaded. `isOn` is the switch in Settings.
    public static func waitingPage(isOn: Bool) -> BrowserLoadFailure {
        if isOn {
            return BrowserLoadFailure(
                title: "Waiting for 1Password",
                message: "This is one of 1Password's own pages. It opens by itself once the "
                    + "extension has loaded.",
                namesTheAddress: false
            )
        }
        return BrowserLoadFailure(
            title: "1Password is switched off",
            message: "This is one of 1Password's own pages. Switch 1Password on in Settings, "
                + "under Browser, and it opens again by itself.",
            namesTheAddress: false
        )
    }
}
