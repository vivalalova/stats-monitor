import SwiftUI

struct NetworkDetailView: View {
    var viewModel: StatsViewModel

    var body: some View {
        DetailPanel(id: .network) {
            let maxVal = max(
                (viewModel.networkInHistory + viewModel.networkOutHistory).max() ?? 1,
                1_048_576
            )

            LineChartView(
                lines: [(viewModel.networkInHistory, .green), (viewModel.networkOutHistory, .red)],
                maxValue: maxVal
            )

            statRow("↓ In",  value: viewModel.networkIn)
            statRow("↑ Out", value: viewModel.networkOut)

            if !viewModel.topNetworkProcesses.isEmpty {
                sectionHeader("Top Processes")
                ForEach(Array(viewModel.topNetworkProcesses.enumerated()), id: \.offset) { _, proc in
                    statRow(proc.name, value: "↓\(viewModel.formatProcessNetwork(proc.networkInBPS)) ↑\(viewModel.formatProcessNetwork(proc.networkOutBPS))")
                }
            }
        }
    }
}

#Preview(.sizeThatFitsLayout) {
    NetworkDetailView(viewModel: StatsViewModel())
}
