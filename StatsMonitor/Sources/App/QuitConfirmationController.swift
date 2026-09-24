import AppKit

enum QuitConfirmationCopy {
    static func title(locale: Locale = .current) -> String {
        LocalizedCopy.string("Quit StatsMonitor?", locale: locale)
    }

    static func message(locale: Locale = .current) -> String {
        LocalizedCopy.string("StatsMonitor will stop monitoring and close.", locale: locale)
    }

    static func confirm(locale: Locale = .current) -> String {
        LocalizedCopy.string("Quit", locale: locale)
    }

    static func cancel(locale: Locale = .current) -> String {
        LocalizedCopy.string("Cancel", locale: locale)
    }
}

enum QuitConfirmationAlertFactory {
    @MainActor
    static func makeAlert(locale: Locale = .current) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = QuitConfirmationCopy.title(locale: locale)
        alert.informativeText = QuitConfirmationCopy.message(locale: locale)
        alert.alertStyle = .warning
        alert.addButton(withTitle: QuitConfirmationCopy.confirm(locale: locale))
        alert.addButton(withTitle: QuitConfirmationCopy.cancel(locale: locale))
        return alert
    }
}
