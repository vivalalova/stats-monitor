import SwiftUI

struct DiskDetailView: View {
    var viewModel: StatsViewModel

    var body: some View {
        DetailPanel(id: .disk) {
            let maxIO = max(
                (viewModel.diskReadHistory + viewModel.diskWriteHistory).max() ?? 1,
                1_048_576
            )

            LineChartView(
                lines: [(viewModel.diskReadHistory, .yellow), (viewModel.diskWriteHistory, .orange)],
                maxValue: maxIO
            )

            statRow("↓ Read",  value: viewModel.diskRead)
            statRow("↑ Write", value: viewModel.diskWrite)
            Divider()
            statRow("Used",  value: viewModel.diskUsed)
            statRow("Free",  value: viewModel.diskFree)
            statRow("Total", value: viewModel.diskTotal)
            if !viewModel.topDiskProcesses.isEmpty {
                sectionHeader("Top Processes")
                ForEach(Array(viewModel.topDiskProcesses.enumerated()), id: \.offset) { _, proc in
                    statRow(proc.name, value: "↓\(viewModel.formatProcessDisk(proc.diskReadBPS)) ↑\(viewModel.formatProcessDisk(proc.diskWriteBPS))")
                }
            }
        }
    }
}

#Preview {
    DiskDetailView(viewModel: StatsViewModel())
}
