import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    static let clickActionMask: NSEvent.EventTypeMask = [.leftMouseDown]

    private let statusItem: NSStatusItem
    private let settings: AppSettings
    private let monitor: SystemMonitor
    private var popover: NSPopover?
    private var currentPanel: PanelID?

    private var statusButton: NSStatusBarButton? {
        statusItem.button
    }

    init(settings: AppSettings, monitor: SystemMonitor) {
        self.settings = settings
        self.monitor = monitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        setupButton()
        observeForLength()
    }

    // MARK: - Setup

    private func setupButton() {
        guard let button = statusButton else { return }
        button.title = ""
        button.image = nil
        button.isBordered = false
        Self.configureClickBehavior(for: button)
        renderButtonLabel()
        button.setAccessibilityLabel("StatsMonitor")
        button.target = self
        button.action = #selector(handleClick(_:))
    }
 
    static func configureClickBehavior(for button: NSStatusBarButton) {
        button.sendAction(on: clickActionMask)
    }

    // MARK: - Length

    private func updateLength() {
        let width = ceil(StatusBarLabelRenderer.measuredTitleWidth(for: currentSegments)) + 12
        if width > 0 {
            statusItem.length = width
        }
    }

    private func renderButtonLabel() {
        guard let button = statusButton else { return }
        button.attributedTitle = StatusBarLabelRenderer.makeAttributedTitle(
            monitor: monitor,
            settings: settings
        )
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
        if closePopoverIfNeeded(for: panel) {
            if currentPanel == panel { currentPanel = nil; return }
        }

        let pop = NSPopover()
        pop.behavior = .transient
        pop.delegate = self
        pop.contentViewController = NSHostingController(rootView: makePopoverContent(for: panel))
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        popover = pop
        currentPanel = panel
    }

    private func closePopoverIfNeeded(for panel: PanelID) -> Bool {
        guard let popover, popover.isShown else { return false }
        popover.close()
        self.popover = nil
        return true
    }

    private func makePopoverContent(for panel: PanelID) -> some View {
        PanelView {
            detailView(for: panel)
        }
        .environment(settings)
        .environment(monitor)
    }

    private var currentSegments: [MenuBarItem] {
        StatusBarLabelRenderer.makeSegments(monitor: monitor, settings: settings)
    }

    // MARK: - Detail views

    @ViewBuilder
    private func detailView(for panel: PanelID) -> some View {
        switch panel {
        case .cpu:     CPUDetailView(monitor: monitor)
        case .gpu:     GPUDetailView(monitor: monitor)
        case .memory:  MemoryDetailView(monitor: monitor)
        case .disk:    DiskDetailView(monitor: monitor)
        case .network: NetworkDetailView(monitor: monitor)
        case .thermal: ThermalDetailView(monitor: monitor)
        case .power:   PowerDetailView(monitor: monitor)
        case .fans:    FansDetailView(monitor: monitor)
        }
    }
}

// MARK: - NSPopoverDelegate

extension StatusBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        popover = nil
        currentPanel = nil
    }
}
