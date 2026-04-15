import SwiftUI

struct ThermalDetailView: View {
    static let panelTitle = "Thermal"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            let lines = thermalLines
            if !lines.isEmpty {
                LineChartView(lines: lines, maxValue: thermalChartMax)
            }

            statRow("CPU", value: monitor.cpuTempText)
            statRow("GPU", value: monitor.gpuTempText)
            statRow("Summary", value: monitor.thermalSummaryText)
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
    ThermalDetailView(monitor: SystemMonitor(settings: AppSettings()))
}
