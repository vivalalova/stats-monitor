import AppKit
import SwiftUI

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let viewModel: StatsViewModel
    private var popover: NSPopover?
    private var currentPanel: PanelID?
    private var hostingView: NSHostingView<CombinedMenuBarLabel>?

    init(viewModel: StatsViewModel) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton()
        observeForLength()
    }

    // MARK: - Setup

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = nil

        let hv = NSHostingView(rootView:
            CombinedMenuBarLabel(viewModel: viewModel, settings: viewModel.settings)
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
        let vm = viewModel
        let s = vm.settings
        withObservationTracking {
            _ = s.showCPU; _ = s.showGPU; _ = s.showMemory
            _ = s.showDisk; _ = s.showNetwork
            _ = vm.cpuPercent; _ = vm.gpuPercent; _ = vm.memoryPercent
            _ = vm.diskPercent; _ = vm.networkIn
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
        let s = viewModel.settings
        let enabled: [PanelID] = [
            s.showCPU ? .cpu : nil, s.showGPU ? .gpu : nil, s.showMemory ? .memory : nil,
            s.showDisk ? .disk : nil, s.showNetwork ? .network : nil,
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

        let content = PanelView(id: panel, content: AnyView(detailView(for: panel)))
            .environment(viewModel.settings)
            .environment(viewModel)

        let pop = NSPopover()
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(rootView: content)
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover = pop
        currentPanel = panel
    }

    private func detailView(for panel: PanelID) -> some View {
        switch panel {
        case .cpu:     AnyView(CPUDetailView(viewModel: viewModel))
        case .gpu:     AnyView(GPUDetailView(viewModel: viewModel))
        case .memory:  AnyView(MemoryDetailView(viewModel: viewModel))
        case .disk:    AnyView(DiskDetailView(viewModel: viewModel))
        case .network: AnyView(NetworkDetailView(viewModel: viewModel))
        }
    }
}
