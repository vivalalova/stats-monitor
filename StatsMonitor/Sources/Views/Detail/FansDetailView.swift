import SwiftUI

struct FansDetailView: View {
    static let panelTitle = "Fans"

    var viewModel: StatsViewModel

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            if viewModel.fanAverageHistory.count >= 2 {
                LineChartView(
                    lines: [(viewModel.fanAverageHistory, .blue)],
                    maxValue: viewModel.fanChartMaxRPM
                )
            }

            statRow("Average", value: viewModel.fansSummary)

            if !viewModel.fans.isEmpty {
                sectionHeader("Per Fan")
                ForEach(Array(viewModel.fans.enumerated()), id: \.element.id) { _, fan in
                    statRow(
                        verbatim: fan.name,
                        value: "\(viewModel.fanRPMStr(fan))  \(viewModel.fanRangeStr(fan))"
                    )
                }
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    FansDetailView(viewModel: StatsViewModel())
}
