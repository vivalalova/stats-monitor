import SwiftUI

struct PowerDetailView: View {
    static let panelTitle = "Power"

    var viewModel: StatsViewModel

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            if viewModel.powerHistory.count >= 2 {
                LineChartView(lines: [(viewModel.powerHistory, .red)])
            }

            statRow("Total", value: viewModel.powerStr)
            statRow("CPU", value: viewModel.cpuPowerStr)
            statRow("GPU", value: viewModel.gpuPowerStr)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    PowerDetailView(viewModel: StatsViewModel())
}
