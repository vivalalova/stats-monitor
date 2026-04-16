import AppKit
import ObjectiveC
import SwiftUI
@testable import StatsMonitor

private var retainedWindowAssociationKey: UInt8 = 0

@MainActor
func alertSnapshotView(_ alert: NSAlert) -> NSView {
    snapshotFrameView(for: alert.window)
}

@MainActor
func appWindowSnapshotView<Content: View>(
    title: String,
    contentSize: CGSize,
    @ViewBuilder content: () -> Content
) -> NSView {
    let hostingController = NSHostingController(rootView: content())
    let window = NSWindow(contentViewController: hostingController)
    window.title = title
    window.setContentSize(contentSize)
    window.isReleasedWhenClosed = false
    window.layoutIfNeeded()
    window.displayIfNeeded()
    return snapshotFrameView(for: window)
}

@MainActor
func detailPopoverSnapshotView(
    panel: PanelID,
    settings: AppSettings,
    monitor: SystemMonitor
) -> NSView {
    let view = NSHostingView(
        rootView: DetailPopoverContentFactory.makeContent(
            for: panel,
            settings: settings,
            monitor: monitor
        )
    )
    let size = view.fittingSize
    view.frame = CGRect(origin: .zero, size: size)
    return view
}

@MainActor
private func snapshotFrameView(for window: NSWindow) -> NSView {
    window.layoutIfNeeded()
    window.displayIfNeeded()

    guard let frameView = window.contentView?.superview else {
        fatalError("Expected window frame view for snapshot")
    }

    frameView.frame = CGRect(origin: .zero, size: window.frame.size)
    objc_setAssociatedObject(
        frameView,
        &retainedWindowAssociationKey,
        window,
        .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
    return frameView
}
