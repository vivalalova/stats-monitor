import SwiftUI

struct ThermalDetailView: View {
    static let panelTitle = "Thermal"

    var viewModel: StatsViewModel

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            let lines = thermalLines
            if !lines.isEmpty {
                LineChartView(lines: lines, maxValue: thermalChartMax)
            }

            statRow("CPU", value: viewModel.cpuTempStr)
            statRow("GPU", value: viewModel.gpuTempStr)
            statRow("Summary", value: viewModel.thermalStatusSummary)
        }
    }

    private var thermalLines: [(history: [Double], color: Color)] {
        var lines: [(history: [Double], color: Color)] = []
        if viewModel.cpuTempHistory.count >= 2 {
            lines.append((viewModel.cpuTempHistory, .orange))
        }
        if viewModel.gpuTempHistory.count >= 2 {
            lines.append((viewModel.gpuTempHistory, .purple))
        }
        return lines
    }

    private var thermalChartMax: Double {
        max(viewModel.cpuTempHistory.max() ?? 0, viewModel.gpuTempHistory.max() ?? 0, 1)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    ThermalDetailView(viewModel: StatsViewModel())
}
