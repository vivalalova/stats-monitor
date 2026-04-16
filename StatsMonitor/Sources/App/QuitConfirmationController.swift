import AppKit
import Observation

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

@MainActor
final class AppTerminationGate {
    static let shared = AppTerminationGate()

    private var isAuthorized = false

    func authorizeNextTermination() {
        isAuthorized = true
    }

    func consumeAuthorization() -> Bool {
        defer { isAuthorized = false }
        return isAuthorized
    }
}

@MainActor
@Observable
final class QuitConfirmationController {
    var isPresented = false

    @ObservationIgnored
    private let terminate: () -> Void

    init(terminate: @escaping () -> Void = {
        AppTerminationGate.shared.authorizeNextTermination()
        NSApplication.shared.terminate(nil)
    }) {
        self.terminate = terminate
    }

    func requestQuit() {
        isPresented = true
    }

    func cancel() {
        isPresented = false
    }

    func confirm() {
        isPresented = false
        terminate()
    }
}
