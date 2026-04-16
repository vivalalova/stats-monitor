import AppKit
@testable import StatsMonitor

@MainActor
func menuBarSnapshotView(monitor: SystemMonitor, settings: AppSettings) -> NSView {
    let button = NSStatusBarButton(frame: .zero)
    StatusBarButtonPresentation.applyLabel(to: button, monitor: monitor, settings: settings)

    let fittingHeight = ceil(button.fittingSize.height)
    let width = StatusBarButtonPresentation.itemLength(monitor: monitor, settings: settings)
    button.frame = CGRect(x: 0, y: 0, width: width, height: max(fittingHeight, 22))
    return button
}
