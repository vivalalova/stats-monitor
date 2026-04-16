import SwiftUI

@MainActor
enum DetailPopoverContentFactory {
    @ViewBuilder
    static func makeContent(
        for panel: PanelID,
        settings: AppSettings,
        monitor: SystemMonitor
    ) -> some View {
        PanelView {
            detailView(for: panel, monitor: monitor)
        }
        .environment(settings)
        .environment(monitor)
    }

    @ViewBuilder
    private static func detailView(for panel: PanelID, monitor: SystemMonitor) -> some View {
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
