import SwiftUI

struct MemoryDetailView: View {
    static let panelTitle = "Memory"

    var viewModel: StatsViewModel

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            if viewModel.memoryHistory.count >= 2 {
                LineChartView(lines: [(viewModel.memoryHistory, .orange)])
            }

            statRow("Used",       value: "\(viewModel.memoryUsed) / \(viewModel.memoryTotal)")
            statRow("Active",     value: viewModel.memoryActive)
            statRow("Wired",      value: viewModel.memoryWired)
            statRow("Compressed", value: viewModel.memoryCompressed)
            if !viewModel.topMemoryProcesses.isEmpty {
                sectionHeader("Top Processes")
                ForEach(Array(viewModel.topMemoryProcesses.enumerated()), id: \.offset) { _, proc in
                    statRow(verbatim: proc.name, value: viewModel.formatProcessMemory(proc.memoryBytes))
                }
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    MemoryDetailView(viewModel: StatsViewModel())
}
