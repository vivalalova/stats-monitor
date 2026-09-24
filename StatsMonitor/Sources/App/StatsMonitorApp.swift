import SwiftUI

@main
struct StatsMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Settings", id: AppSceneID.settingsWindow) {
            MainWindowView(settings: appDelegate.settings, monitor: appDelegate.monitor)
                .onAppear { appDelegate.settings.refreshLaunchAtLoginState() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    appDelegate.settings.refreshLaunchAtLoginState()
                }
        }
        .defaultSize(
            width: SettingsWindowLayout.defaultWidth,
            height: SettingsWindowLayout.defaultHeight
        )
        // 視窗尺寸鎖定為 contentSize，禁止使用者調整；MainWindowView 已套用同一份 layout contract。
        // 刻意設計，不得改動。
        .windowResizability(.contentSize)
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
        if Self.isSystemInitiatedQuit(NSAppleEventManager.shared().currentAppleEvent) { return .terminateNow }
        let alert = QuitConfirmationAlertFactory.makeAlert()
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }

    private static let systemQuitReasons = Set([
        kAEQuitAll, kAELogOut, kAEReallyLogOut, kAEShowRestartDialog, kAERestart, kAEShowShutdownDialog, kAEShutDown,
    ].map { OSType($0) })

    /// Logout / restart / shutdown must not be blocked by a modal; only a user-initiated quit asks.
    static func isSystemInitiatedQuit(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event, event.eventID == OSType(kAEQuitApplication) else { return false }
        let keyword = AEKeyword(kAEQuitReason)
        guard let reason = event.attributeDescriptor(forKeyword: keyword) ?? event.paramDescriptor(forKeyword: keyword)
        else { return false }
        return systemQuitReasons.contains(reason.enumCodeValue)
    }
}
