import AppKit

/// 結束行程相關 alert 的文案。與 `QuitConfirmationCopy` 同理：AppKit alert 手動組字，
/// 需要能在測試裡指定 locale，所以不走 `LocalizedStringKey`。
enum ProcessTerminationCopy {
    static func forceQuitTitle(processName: String, locale: Locale = .current) -> String {
        LocalizedCopy.string("Force Quit %@?", locale: locale, arguments: [processName])
    }

    static func forceQuitMessage(locale: Locale = .current) -> String {
        LocalizedCopy.string(
            "Force quitting ends the process immediately. Unsaved changes will be lost.",
            locale: locale
        )
    }

    static func forceQuitConfirm(locale: Locale = .current) -> String {
        LocalizedCopy.string("Force Quit", locale: locale)
    }

    static func cancel(locale: Locale = .current) -> String {
        LocalizedCopy.string("Cancel", locale: locale)
    }

    static func failureTitle(processName: String, locale: Locale = .current) -> String {
        LocalizedCopy.string("Unable to quit %@", locale: locale, arguments: [processName])
    }

    /// 人話句子＋系統 errno 描述；`invalidPID` 不是 `kill(2)` 失敗，沒有 errno 段可附。
    static func failureMessage(error: ProcessTerminationError, locale: Locale = .current) -> String {
        let sentence = LocalizedCopy.string(sentenceKey(for: error), locale: locale)
        guard let errorNumber = error.errorNumber else { return sentence }
        return "\(sentence) (\(String(cString: strerror(errorNumber))))"
    }

    static func dismiss(locale: Locale = .current) -> String {
        LocalizedCopy.string("OK", locale: locale)
    }

    private static func sentenceKey(for error: ProcessTerminationError) -> String {
        switch error {
        case .invalidPID:       "This process does not report a valid process ID."
        case .permissionDenied: "StatsMonitor does not have permission to quit this process."
        case .noSuchProcess:    "The process is no longer running."
        case .other:            "The process could not be quit."
        }
    }
}

@MainActor
enum ProcessTerminationAlertFactory {
    /// 強制結束前的確認；預設鍵是 Force Quit，Cancel 排第二讓 Esc 取消。
    static func makeForceQuitConfirmation(processName: String, locale: Locale = .current) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = ProcessTerminationCopy.forceQuitTitle(processName: processName, locale: locale)
        alert.informativeText = ProcessTerminationCopy.forceQuitMessage(locale: locale)
        alert.alertStyle = .warning
        alert.addButton(withTitle: ProcessTerminationCopy.forceQuitConfirm(locale: locale))
        alert.addButton(withTitle: ProcessTerminationCopy.cancel(locale: locale))
        return alert
    }

    static func makeFailureAlert(
        processName: String,
        error: ProcessTerminationError,
        locale: Locale = .current
    ) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = ProcessTerminationCopy.failureTitle(processName: processName, locale: locale)
        alert.informativeText = ProcessTerminationCopy.failureMessage(error: error, locale: locale)
        alert.alertStyle = .warning
        alert.addButton(withTitle: ProcessTerminationCopy.dismiss(locale: locale))
        return alert
    }
}
