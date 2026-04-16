import SwiftUI

struct ThermalDetailView: View {
    static let panelTitle = "Thermal"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            DetailChart(lines: thermalLines, maxValue: thermalChartMax)
            DetailMetricSection(rows: [
                ("CPU", monitor.cpuTempText),
                ("GPU", monitor.gpuTempText),
                ("Summary", monitor.thermalSummaryText),
            ])
            DetailMetricSection(title: "System", rows: availableDetailMetrics([
                ("System Power", monitor.powerText),
                ("Fans", monitor.fansSummaryText),
            ]))
        }
    }

    private var thermalLines: [(history: [Double], color: Color)] {
        var lines: [(history: [Double], color: Color)] = []
        if monitor.paddedCPUTempHistory.count >= 2 {
            lines.append((monitor.paddedCPUTempHistory, .orange))
        }
        if monitor.paddedGPUTempHistory.count >= 2 {
            lines.append((monitor.paddedGPUTempHistory, .purple))
        }
        return lines
    }

    private var thermalChartMax: Double {
        max(monitor.paddedCPUTempHistory.max() ?? 0, monitor.paddedGPUTempHistory.max() ?? 0, 1)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    ThermalDetailView(monitor: SystemMonitor(settings: AppSettings()).start())
}
