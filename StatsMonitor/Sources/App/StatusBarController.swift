import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let settings: AppSettings
    private let monitor: SystemMonitor
    private var popover: NSPopover?
    private var currentPanel: PanelID?
    private var hostingView: NSHostingView<CombinedMenuBarLabel>?

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
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = nil

        let hv = NSHostingView(rootView:
            CombinedMenuBarLabel(monitor: monitor, settings: settings)
        )
        hv.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hv)
        NSLayoutConstraint.activate([
            hv.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hv.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])
        hostingView = hv

        button.target = self
        button.action = #selector(handleClick(_:))
    }

    // MARK: - Length

    private func updateLength() {
        guard let hv = hostingView else { return }
        hv.layoutSubtreeIfNeeded()
        let w = hv.fittingSize.width
        if w > 0 { statusItem.length = w }
    }

    /// 觀察所有影響 label 寬度的值（指標數值 + show 設定），任一改變就重算 length
    private func observeForLength() {
        let s = settings
        let m = monitor
        withObservationTracking {
            _ = s.showCPU; _ = s.showGPU; _ = s.showMemory
            _ = s.showDisk; _ = s.showNetwork
            _ = s.showBattery; _ = s.showThermal; _ = s.showPower; _ = s.showFans
            _ = m.cpuPercent; _ = m.gpuPercent; _ = m.memoryPercent
            _ = m.diskPercent; _ = m.networkInText
            _ = m.hasBattery; _ = m.hasThermal; _ = m.hasPower; _ = m.hasFans
            _ = m.batteryPercent; _ = m.cpuTempText; _ = m.powerText; _ = m.fansSummaryText
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
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
        let s = settings
        let enabled: [PanelID] = [
            s.showCPU ? .cpu : nil, s.showGPU ? .gpu : nil, s.showMemory ? .memory : nil,
            s.showDisk ? .disk : nil, s.showNetwork ? .network : nil,
            s.showBattery && monitor.hasBattery ? .battery : nil,
            s.showThermal && monitor.hasThermal ? .thermal : nil,
            s.showPower && monitor.hasPower ? .power : nil,
            s.showFans && monitor.hasFans ? .fans : nil,
        ].compactMap { $0 }
        guard !enabled.isEmpty else { return .cpu }
        let slotWidth = statusItem.length / CGFloat(enabled.count)
        let index = min(Int(x / slotWidth), enabled.count - 1)
        return enabled[max(index, 0)]
    }

    // MARK: - Popover

    private func toggle(panel: PanelID, relativeTo button: NSView) {
        if let pop = popover, pop.isShown {
            pop.close()
            popover = nil
            if currentPanel == panel { currentPanel = nil; return }
        }

        let content = PanelView {
            detailView(for: panel)
        }
            .environment(settings)
            .environment(monitor)

        let pop = NSPopover()
        pop.behavior = .transient
        pop.delegate = self
        pop.contentViewController = NSHostingController(rootView: content)
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        popover = pop
        currentPanel = panel
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
        case .battery: BatteryDetailView(monitor: monitor)
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
