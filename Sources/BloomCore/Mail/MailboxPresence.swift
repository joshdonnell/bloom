import Foundation

/// Whether the inspector offers a Mail tab, and how hard Bloom looks for a Mailpit to fill it.
///
/// **The tab appears the first time Mailpit answers and then stays for the rest of the launch.**
/// Following the server live was the other way to do it, and it would have taken the tab away
/// from under somebody reading a message the moment they stopped Mailpit to restart it, dropping
/// the inspector back to Changes mid-sentence. Sticky means the person who has a Mailpit gets a tab
/// that says "disconnected, retrying" instead, and the person who has none never sees one at all.
///
/// Changing the address starts over, because an answer from the old address says nothing about
/// the new one.
public struct MailboxPresence: Equatable, Sendable {
    public private(set) var isEnabled: Bool
    public private(set) var hasAnswered = false

    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    public var showsTab: Bool { isEnabled && hasAnswered }

    /// Whether to keep knocking on a port that has never answered, every `searchInterval`.
    ///
    /// Only until the first answer. After that the websocket's own reconnect is doing the looking,
    /// and at its own pace: see `reconnectDelay`.
    public var isSearching: Bool { isEnabled && !hasAnswered }

    /// How often to look for a Mailpit that has not answered yet. Each look is one request to a
    /// port on this Mac, which costs nothing when nothing is listening.
    public static let searchInterval: Duration = .seconds(30)

    public mutating func answered() {
        guard isEnabled else { return }
        hasAnswered = true
    }

    /// Settings changed: switched off, switched on, or pointed somewhere else.
    public mutating func reconfigure(isEnabled: Bool) {
        self.isEnabled = isEnabled
        hasAnswered = false
    }

    /// How long to wait before reconnecting, after `failures` attempts in a row have failed.
    ///
    /// One second, doubling, held at thirty. A Mailpit being restarted is back within a couple of
    /// seconds, so the first retries find it quickly. One that has been stopped for the afternoon
    /// is asked twice a minute, which is the same pace as `searchInterval`.
    public static func reconnectDelay(afterFailures failures: Int) -> Duration {
        guard failures > 0 else { return .zero }
        let exponent = min(failures - 1, 5)
        return min(.seconds(1 << exponent), .seconds(30))
    }
}
