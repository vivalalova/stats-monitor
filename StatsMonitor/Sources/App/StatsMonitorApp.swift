import SwiftUI

@main
struct StatsMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(settings: appDelegate.viewModel.settings, viewModel: appDelegate.viewModel)
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = StatsViewModel()
    private var controller: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusBarController(viewModel: viewModel)
    }
}
