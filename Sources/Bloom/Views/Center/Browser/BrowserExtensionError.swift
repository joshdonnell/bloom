import Foundation

/// What Bloom tells the browser extension when it cannot do what was asked, so the extension
/// can react rather than carrying on as though it had been done.
enum BrowserExtensionError: LocalizedError {
    case cannotOpenTab
    case cannotShowPopup

    var errorDescription: String? {
        switch self {
        case .cannotOpenTab: "Bloom could not open a tab for the extension."
        case .cannotShowPopup: "Bloom had nowhere on screen to show the extension's popup."
        }
    }
}
