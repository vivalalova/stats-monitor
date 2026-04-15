import SwiftUI
import Util

struct CPUDetailView: View {
    var viewModel: StatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.cpuHistory.count >= 2 {
                LineChartView(lines: [(viewModel.cpuHistory, .blue)])
            }

            statRow("Used",   value: viewModel.cpuPercent)
            statRow("User",   value: viewModel.cpuUserPercent)
            statRow("System", value: viewModel.cpuSystemPercent)
            statRow("Idle",   value: String(format: "%.1f%%", viewModel.monitor.stats.cpu.idle))
            if !viewModel.cpuPerCore.isEmpty {
                sectionHeader("Per Core")
                CoreGridView(cores: viewModel.cpuPerCore,
                             frequencies: viewModel.cpuCoreFrequencies)
            }

            if !viewModel.topCPUProcesses.isEmpty {
                sectionHeader("Top Processes")
                ForEach(Array(viewModel.topCPUProcesses.enumerated()), id: \.offset) { _, proc in
                    statRow(verbatim: proc.name, value: viewModel.formatProcessCPU(proc.cpuPercent))
                }
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    CPUDetailView(viewModel: StatsViewModel())
}

// MARK: - Core grid

private struct CoreGridView: View {
    var cores: [Double]
    var frequencies: [CPUCoreFrequency] = []

    // ≤10 cores → fill the full row; >10 → always use 10-column width
    private var effectiveColumns: Int { min(cores.count, 10) }

    private var barWidth: CGFloat {
        (BarMetrics.contentWidth - BarMetrics.spacing * CGFloat(effectiveColumns - 1)) / CGFloat(effectiveColumns)
    }

    private var rows: [[(index: Int, value: Double)]] {
        let items = cores.enumerated().map { (index: $0.offset, value: $0.element) }
        return stride(from: 0, to: items.count, by: effectiveColumns).map {
            Array(items[$0 ..< min($0 + effectiveColumns, items.count)])
        }
    }

    // P-cores (blue) come first in the frequencies array with higher maxHz;
    // E-cores (green) follow with lower maxHz.
    // Returns nil when cluster distinction is unavailable.
    private var pCoreCount: Int? {
        guard !frequencies.isEmpty else { return nil }
        let distinctMax = Set(frequencies.map(\.maxHz).filter { $0 > 0 })
        guard distinctMax.count >= 2, let highMax = distinctMax.max() else { return nil }
        return frequencies.prefix(while: { $0.maxHz == highMax }).count
    }

    private func barColor(for index: Int) -> Color {
        guard let pCount = pCoreCount else { return progressColor(cores[index] / 100) }
        return index < pCount ? .blue : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .bottom, spacing: BarMetrics.spacing) {
                    ForEach(row, id: \.index) { item in
                        let freq = item.index < frequencies.count ? frequencies[item.index] : .zero
                        VStack(spacing: 1) {
                            BarView(width: barWidth, color: barColor(for: item.index), value: item.value)
                            if freq.currentHz > 0 {
                                Text(ghzString(freq.currentHz))
                            }
                            Text("\(Int(item.value))%")
                        }
                        .font(.system(size: 9))
                        .monospacedDigit()
                    }
                }
            }
        }
    }

}
