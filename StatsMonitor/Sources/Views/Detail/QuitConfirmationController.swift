import AppKit
import Observation

enum QuitConfirmationCopy {
    static let title = "Quit StatsMonitor?"
    static let message = "StatsMonitor will stop monitoring and close."
    static let confirm = "Quit"
    static let cancel = "Cancel"
}

@MainActor
@Observable
final class QuitConfirmationController {
    var isPresented = false

    @ObservationIgnored
    private let terminate: () -> Void

    init(terminate: @escaping () -> Void = {
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
