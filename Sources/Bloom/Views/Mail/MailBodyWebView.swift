import SwiftUI
import WebKit
import BloomCore

/// A message's HTML body, drawn by WebKit from Mailpit's own preview route.
///
/// **Mailpit's `view/<id>.html` rather than the `HTML` field of the message.** The field is the
/// part as it arrived, and an image embedded in the message is a `cid:` reference in it that no web
/// view can follow. Mailpit's preview rewrites those to its part routes, so inline logos load.
///
/// **No JavaScript.** Mail clients run none, so an email that only works with it is an email that
/// is broken for its readers, and the preview should show that rather than hide it. Remote images
/// do load: this is mail the reader's own app just sent, and a template with its images stripped
/// looks broken in a way the real thing is not.
///
/// **A link opens in the workspace's browser tab**, not here and not in another app. Test mail is
/// mostly verification and reset links pointing at the dev server, and the browser tab beside the
/// mail is where that server already is. Anything that is not http or https is left alone.
struct MailBodyWebView: NSViewRepresentable {
    var url: URL
    var onLink: @MainActor (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLink: onLink)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        // Nothing an email sets, a cookie or local storage, outlives the view or reaches the
        // browser tabs' own store.
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.onLink = onLink
        guard context.coordinator.loaded != url else { return }
        context.coordinator.loaded = url
        view.load(URLRequest(url: url))
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var onLink: @MainActor (URL) -> Void
        var loaded: URL?

        init(onLink: @escaping @MainActor (URL) -> Void) {
            self.onLink = onLink
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            // The body itself loads, and so do the frames and images it pulls in. Nothing else
            // may move this view: a form in an email posting from here would put a page from the
            // reader's app where the message was, under headers that no longer describe it.
            switch navigationAction.navigationType {
            case .other where navigationAction.request.url == loaded || navigationAction.targetFrame?.isMainFrame == false:
                return .allow
            case .linkActivated:
                if let url = navigationAction.request.url, BrowserTab.canOpen(url) { onLink(url) }
                return .cancel
            default:
                return .cancel
            }
        }
    }
}
