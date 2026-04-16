import AppKit
import Observation

enum QuitConfirmationCopy {
    static let title = "Quit StatsMonitor?"
    static let message = "StatsMonitor will stop monitoring and close."
    static let confirm = "Quit"
    static let cancel = "Cancel"
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
