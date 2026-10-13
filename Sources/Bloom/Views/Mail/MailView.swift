import SwiftUI

/// The app's Mailpit inbox. One server is configured for Bloom, so its messages have one
/// destination outside the workspace inspector.
struct MailView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        HSplitView {
            MailListPane()
                .frame(minWidth: 280, idealWidth: 340, maxWidth: 480)
            MailPaneView()
                .frame(minWidth: 360, maxWidth: .infinity)
        }
        .background(Palette.surface)
        .onChange(of: Mailbox.shared.link.presence.isEnabled) { _, enabled in
            if !enabled { app.selection = .home }
        }
    }
}
