import AppKit
import SwiftUI

@MainActor
enum StatusBarButtonPresentation {
    static func itemLength(monitor: SystemMonitor, settings: AppSettings) -> CGFloat {
        let segments = StatusBarLabelRenderer.makeSegments(monitor: monitor, settings: settings)
        return ceil(StatusBarLabelRenderer.measuredTitleWidth(for: segments)) + 12
    }

    static func applyLabel(
        to button: NSStatusBarButton,
        monitor: SystemMonitor,
        settings: AppSettings
    ) {
        button.title = ""
        button.image = nil
        button.isBordered = false
        button.attributedTitle = StatusBarLabelRenderer.makeAttributedTitle(
            monitor: monitor,
            settings: settings
        )
    }
}

@MainActor
final class StatusBarController: NSObject {
    static let clickActionMask: NSEvent.EventTypeMask = [.leftMouseDown]

    private let statusItem: NSStatusItem
    private let settings: AppSettings
    private let monitor: SystemMonitor
    private let popover: NSPopover
    private let popoverContentController: NSHostingController<AnyView>
    private var currentPanel: PanelID?

    private var statusButton: NSStatusBarButton? {
        statusItem.button
    }

    init(settings: AppSettings, monitor: SystemMonitor) {
        self.settings = settings
        self.monitor = monitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popoverContentController = NSHostingController(rootView: AnyView(EmptyView()))
        super.init()
        Self.configurePopoverBehavior(for: popover)
        popover.delegate = self
        popover.contentViewController = popoverContentController
        setupButton()
        observeForLength()
    }

    // MARK: - Setup

    private func setupButton() {
        guard let button = statusButton else { return }
        StatusBarButtonPresentation.applyLabel(to: button, monitor: monitor, settings: settings)
        Self.configureClickBehavior(for: button)
        button.setAccessibilityLabel("StatsMonitor")
        button.target = self
        button.action = #selector(handleClick(_:))
    }
 
    static func configureClickBehavior(for button: NSStatusBarButton) {
        button.sendAction(on: clickActionMask)
    }

    static func configurePopoverBehavior(for popover: NSPopover) {
        popover.behavior = .transient
        popover.animates = false
    }

    // MARK: - Length

    private func updateLength() {
        let width = StatusBarButtonPresentation.itemLength(monitor: monitor, settings: settings)
        if width > 0 {
            statusItem.length = width
        }
    }

    private func renderButtonLabel() {
        guard let button = statusButton else { return }
        StatusBarButtonPresentation.applyLabel(to: button, monitor: monitor, settings: settings)
    }

    /// 觀察所有影響 label 寬度的值（指標數值 + show 設定），任一改變就重算 length
    private func observeForLength() {
        withObservationTracking {
            _ = currentSegments
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.renderButtonLabel()
                self?.updateLength()
                self?.observeForLength()
            }
        }
    }

    // MARK: - Click handling

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let x = sender.convert(event.locationInWindow, from: nil).x
        toggle(panel: panelAt(x: x), relativeTo: sender)
    }

    private func panelAt(x: CGFloat) -> PanelID {
        StatusBarLabelRenderer.panel(at: x, in: currentSegments) ?? .cpu
    }

    // MARK: - Popover

    private func toggle(panel: PanelID, relativeTo button: NSView) {
        if popover.isShown, currentPanel == panel {
            popover.performClose(nil)
            return
        }

        updatePopoverContent(for: panel)
        if popover.isShown {
            popover.performClose(nil)
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        currentPanel = panel
    }

    private func updatePopoverContent(for panel: PanelID) {
        popoverContentController.rootView = AnyView(
            DetailPopoverContentFactory.makeContent(
                for: panel,
                settings: settings,
                monitor: monitor
            )
        )
    }

    private var currentSegments: [MenuBarItem] {
        StatusBarLabelRenderer.makeSegments(monitor: monitor, settings: settings)
    }
}

// MARK: - NSPopoverDelegate

extension StatusBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        currentPanel = nil
    }
}
