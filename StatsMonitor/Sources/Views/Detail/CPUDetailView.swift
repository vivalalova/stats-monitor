import SwiftUI
import Util

struct CPUDetailView: View {
    static let panelTitle = "CPU"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            DetailChart(lines: [(monitor.paddedCPUHistory, .blue)])
            DetailMetricSection(rows: [
                ("Used", monitor.cpuPercent),
                ("User", monitor.cpuUserPercent),
                ("System", monitor.cpuSystemPercent),
                ("Idle", monitor.cpuIdlePercent),
            ])
            DetailMetricSection(title: "System", rows: [
                ("Temperature", monitor.cpuTempText),
                ("CPU Power", monitor.cpuPowerText),
                ("System Power", monitor.powerText),
            ])
            DetailMetricSection(title: "Frequency", rows: [
                ("Average", monitor.cpuAverageFrequencyText),
                ("Peak", monitor.cpuPeakFrequencyText),
            ])
            if !monitor.cpuPerCore.isEmpty {
                sectionHeader("Per Core")
                CoreGridView(
                    cores: monitor.cpuPerCore,
                    frequencies: monitor.cpuCoreFrequencies
                )
            }
            DetailListSection(
                "Top Processes",
                data: Array(monitor.topCPUProcesses.enumerated()),
                id: \.offset
            ) { entry in
                statRow(verbatim: entry.element.name, value: monitor.formatProcessCPU(entry.element.cpuPercent))
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    CPUDetailView(monitor: SystemMonitor(settings: AppSettings()))
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
