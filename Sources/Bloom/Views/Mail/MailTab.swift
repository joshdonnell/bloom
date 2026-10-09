import SwiftUI
import BloomCore

/// The one way a message gets into the centre column, and the one way it leaves the mailbox.
///
/// The same shape as `WorkspaceNotes` and `FileReview`, and for their reason: a workspace has one
/// mail tab, so every route to a message has to land on that tab rather than open another, and the
/// three gestures that move it (a click, Return, an arrow key) differ only in whether it comes
/// forward.
@MainActor
enum MailTab {
    /// A click or Return: the tab is pointed at the message and brought forward.
    ///
    /// `reveal` without focusing, as a filename clicked in the changed list does: the reader is
    /// standing in the inspector, and a mail tab already on screen in one half of a split is not
    /// dragged into the half they were typing in.
    static func open(_ id: MailpitMessageID, in model: WorkspaceModel) {
        let mailbox = Mailbox.shared
        mailbox.select(id)
        let subject = mailbox.list.summary(id)?.subject ?? ""
        let tab = CenterTabStore.shared.showMail(workspaceID: model.workspace.id, message: id, subject: subject)
        WorkspaceTabsStore.shared.reveal(.tool(tab.id), in: model)
    }

    /// An arrow key: the selection moves, and a mail tab that is already open follows it where it
    /// is. One that is not open is left closed, because walking a list is not asking for a tab.
    static func follow(_ id: MailpitMessageID, in model: WorkspaceModel) {
        let mailbox = Mailbox.shared
        mailbox.select(id)
        guard let tab = CenterTabStore.shared.mail(for: model.workspace.id) else { return }
        CenterTabStore.shared.pointMail(tab, at: id, subject: mailbox.list.summary(id)?.subject ?? "")
    }

    /// Deletes a message, and moves the selection and this workspace's mail tab on to the next
    /// older one, so deleting a run of test mail is one key pressed several times. With nothing
    /// left to move to, the tab stays where it is and says the message has gone.
    static func delete(_ id: MailpitMessageID, in model: WorkspaceModel) {
        let mailbox = Mailbox.shared
        let next = mailbox.list.successor(afterRemoving: id)
        let wasSelected = mailbox.selection == id
        let tab = CenterTabStore.shared.mail(for: model.workspace.id)
        mailbox.delete(id)

        guard let next else {
            if wasSelected { mailbox.select(nil) }
            return
        }
        let showsNext = tab?.mailMessage == id
        // Read only when the tab is about to show it. See `Mailbox.select`.
        if wasSelected { mailbox.select(next, markingRead: showsNext) }
        if let tab, showsNext {
            CenterTabStore.shared.pointMail(tab, at: next, subject: mailbox.list.summary(next)?.subject ?? "")
        }
    }
}
