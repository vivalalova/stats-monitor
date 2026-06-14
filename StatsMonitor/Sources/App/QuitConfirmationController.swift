import AppKit

enum QuitConfirmationCopy {
    static func title(locale: Locale = .current) -> String {
        localized("Quit StatsMonitor?", locale: locale)
    }

    static func message(locale: Locale = .current) -> String {
        localized("StatsMonitor will stop monitoring and close.", locale: locale)
    }

    static func confirm(locale: Locale = .current) -> String {
        localized("Quit", locale: locale)
    }

    static func cancel(locale: Locale = .current) -> String {
        localized("Cancel", locale: locale)
    }

    private static func localized(_ key: String, locale: Locale) -> String {
        let localization = Bundle.preferredLocalizations(
            from: Bundle.main.localizations,
            forPreferences: [locale.identifier]
        ).first

        let bundle = localization
            .flatMap { Bundle.main.path(forResource: $0, ofType: "lproj") }
            .flatMap(Bundle.init(path:)) ?? .main

        return bundle.localizedString(forKey: key, value: nil, table: nil)
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
