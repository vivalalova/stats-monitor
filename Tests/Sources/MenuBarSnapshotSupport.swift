import AppKit
@testable import StatsMonitor

@MainActor
func menuBarSnapshotView(monitor: SystemMonitor, settings: AppSettings) -> NSView {
    StatusBarButtonPresentation.makeStandaloneButton(monitor: monitor, settings: settings)
}
