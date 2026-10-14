import SwiftUI

/// The app's Mailpit inbox, opened from the sidebar footer. One server is configured for Bloom,
/// so its messages have one destination outside the workspace inspector.
struct MailView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        GeometryReader { geometry in
            let listWidth = min(420, max(300, geometry.size.width * 0.36))

            HStack(spacing: 0) {
                MailListPane()
                    .frame(width: listWidth, height: geometry.size.height)
                Hairline(axis: .vertical)
                    .frame(height: geometry.size.height)
                MailPaneView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Palette.surface)
        }
        .background(Palette.surface)
        .onChange(of: Mailbox.shared.link.presence.isEnabled) { _, enabled in
            if !enabled { app.selection = .home }
        }
    }
}
