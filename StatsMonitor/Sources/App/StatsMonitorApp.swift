import SwiftUI

@main
struct StatsMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Settings", id: AppSceneID.settingsWindow) {
            MainWindowView(settings: appDelegate.settings, monitor: appDelegate.monitor)
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
    let settings = AppSettings()
    lazy var monitor = SystemMonitor(settings: settings)
    private var controller: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.start()
        controller = StatusBarController(settings: settings, monitor: monitor)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        quitConfirmationReply()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func quitConfirmationReply() -> NSApplication.TerminateReply {
        let alert = QuitConfirmationAlertFactory.makeAlert()
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}
