import AppKit

enum QuitConfirmationCopy {
    static let title = "Quit StatsMonitor?"
    static let message = "StatsMonitor will stop monitoring and close."
    static let confirm = "Quit"
    static let cancel = "Cancel"
}

enum QuitConfirmationAlertFactory {
    @MainActor
    static func makeAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = QuitConfirmationCopy.title
        alert.informativeText = QuitConfirmationCopy.message
        alert.alertStyle = .warning
        alert.addButton(withTitle: QuitConfirmationCopy.confirm)
        alert.addButton(withTitle: QuitConfirmationCopy.cancel)
        return alert
    }
}
