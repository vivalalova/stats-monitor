import SwiftUI

@main
struct StatsMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Settings", id: AppSceneID.settingsWindow) {
            SettingsView(settings: appDelegate.viewModel.settings, viewModel: appDelegate.viewModel)
        }
        .defaultSize(
            width: SettingsWindowLayout.defaultWidth,
            height: SettingsWindowLayout.defaultHeight
        )
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .commands {
            SettingsCommands()
        }
    }
}

private struct SettingsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                openWindow(id: AppSceneID.settingsWindow)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = StatsViewModel()
    private var controller: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusBarController(viewModel: viewModel)
    }
}
