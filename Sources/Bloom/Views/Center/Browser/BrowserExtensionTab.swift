import AppKit
import WebKit

/// A Bloom browser tab as a web extension sees it.
///
/// Its own object rather than a conformance on `BrowserSession`, because `WKWebExtensionTab`
/// inherits from `NSObjectProtocol` and the session is a plain Swift class. Owned by the session,
/// pointing back at it weakly, so the extension never keeps a closed tab alive.
///
/// Only what 1Password needs is answered. Pinning, muting, reader mode, zoom and duplication are
/// left to WebKit's defaults, which report them as unsupported, and that is the truth here.
@MainActor
final class BrowserExtensionTab: NSObject, WKWebExtensionTab {
    weak var session: BrowserSession?

    init(session: BrowserSession) {
        self.session = session
    }

    private var host: BrowserExtensionHost { .shared }

    func window(for context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        context.focusedWindow
    }

    func indexInWindow(for context: WKWebExtensionContext) -> Int {
        host.index(of: self)
    }

    func webView(for context: WKWebExtensionContext) -> WKWebView? {
        session?.webView
    }

    func title(for context: WKWebExtensionContext) -> String? {
        session?.webView.title
    }

    func url(for context: WKWebExtensionContext) -> URL? {
        session?.webView.url
    }

    func isLoadingComplete(for context: WKWebExtensionContext) -> Bool {
        !(session?.isLoading ?? false)
    }

    func isSelected(for context: WKWebExtensionContext) -> Bool {
        host.isActive(self)
    }

    func size(for context: WKWebExtensionContext) -> CGSize {
        session?.webView.bounds.size ?? .zero
    }

    /// Granting the extension the page under it when the reader presses its button or uses its
    /// shortcut, which is the `activeTab` permission and the reason 1Password can fill at all.
    func shouldGrantPermissionsOnUserGesture(for context: WKWebExtensionContext) -> Bool {
        true
    }

    func activate(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        host.activate(self)
        completionHandler(nil)
    }

    func loadURL(
        _ url: URL, for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void
    ) {
        session?.webView.load(URLRequest(url: url))
        completionHandler(nil)
    }

    func reload(
        fromOrigin: Bool, for context: WKWebExtensionContext,
        completionHandler: @escaping ((any Error)?) -> Void
    ) {
        if fromOrigin { session?.webView.reloadFromOrigin() } else { session?.reload() }
        completionHandler(nil)
    }

    func goBack(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        session?.goBack()
        completionHandler(nil)
    }

    func goForward(for context: WKWebExtensionContext, completionHandler: @escaping ((any Error)?) -> Void) {
        session?.goForward()
        completionHandler(nil)
    }
}
