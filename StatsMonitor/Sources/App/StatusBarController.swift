import AppKit
import SwiftUI

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let viewModel: StatsViewModel
    private var popover: NSPopover?
    private var currentPanel: PanelID?

    init(viewModel: StatsViewModel) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton()
        updateLength()
        observeSettings()
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
            hv.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hv.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])

        button.target = self
        button.action = #selector(handleClick(_:))
    }

    // MARK: - Length

    private func updateLength() {
        let s = viewModel.settings
        let slots: [(Bool, CGFloat)] = [
            (s.showCPU, 80), (s.showGPU, 80), (s.showMemory, 80),
            (s.showDisk, 80), (s.showNetwork, 95),
        ]
        let enabled = slots.filter(\.0)
        statusItem.length = enabled.isEmpty
            ? 30
            : enabled.map(\.1).reduce(0, +) + CGFloat(enabled.count - 1) * 4
    }

    private func observeSettings() {
        let s = viewModel.settings
        withObservationTracking {
            _ = s.showCPU; _ = s.showGPU; _ = s.showMemory
            _ = s.showDisk; _ = s.showNetwork
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateLength()
                self?.observeSettings()
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
        let ordered: [(PanelID, CGFloat, Bool)] = [
            (.cpu, 80, s.showCPU), (.gpu, 80, s.showGPU), (.memory, 80, s.showMemory),
            (.disk, 80, s.showDisk), (.network, 95, s.showNetwork),
        ]
        var cursor: CGFloat = 0
        for (id, width, enabled) in ordered where enabled {
            if x <= cursor + width { return id }
            cursor += width + 4
        }
        return ordered.filter(\.2).last?.0 ?? .cpu
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
