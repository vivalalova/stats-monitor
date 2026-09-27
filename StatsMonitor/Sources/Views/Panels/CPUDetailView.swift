import SwiftUI
import Util

struct CPUDetailView: View {
    static let panelTitle = "CPU"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            DetailChart(lines: [ChartSeries(history: monitor.paddedCPUHistory, color: .blue)])
            DetailMetricSection(rows: [
                ("Used", monitor.cpuPercent),
                ("User", monitor.cpuUserPercent),
                ("System", monitor.cpuSystemPercent),
                ("Idle", monitor.cpuIdlePercent),
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
    CPUDetailView(monitor: SystemMonitor(settings: AppSettings()).start())
}

// MARK: - Core grid

private struct CoreGridView: View {
    var cores: [Double]
    var frequencies: [CPUCoreFrequency] = []

    private struct Core {
        var index: Int
        var usage: Double
        var frequency: CPUCoreFrequency
    }

    private struct CoreGroup {
        var title: LocalizedStringKey?
        var color: Color?
        var cores: [Core]
    }

    private static let barWidth: CGFloat = 36
    private static let columns = Int((BarMetrics.contentWidth + BarMetrics.spacing) / (barWidth + BarMetrics.spacing))

    private var groups: [CoreGroup] {
        let all = cores.indices.map { index in
            Core(
                index: index,
                usage: cores[index],
                frequency: frequencies.indices.contains(index) ? frequencies[index] : .zero
            )
        }
        guard frequencies.count == cores.count, frequencies.allSatisfy({ $0.isPerformanceCore != nil }) else {
            return [CoreGroup(title: nil, color: nil, cores: all)]
        }
        return [
            CoreGroup(title: "Performance Cores", color: .blue, cores: all.filter { $0.frequency.isPerformanceCore == true }),
            CoreGroup(title: "Efficiency Cores", color: .green, cores: all.filter { $0.frequency.isPerformanceCore == false }),
        ].filter { !$0.cores.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                if let title = group.title {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(rows(of: group.cores).enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .bottom, spacing: BarMetrics.spacing) {
                        ForEach(row, id: \.index) { core in
                            coreColumn(core, color: group.color ?? progressColor(core.usage / 100))
                        }
                    }
                }
            }
        }
    }

    private func rows(of cores: [Core]) -> [[Core]] {
        stride(from: 0, to: cores.count, by: Self.columns).map {
            Array(cores[$0 ..< min($0 + Self.columns, cores.count)])
        }
    }

    private func coreColumn(_ core: Core, color: Color) -> some View {
        VStack(spacing: 1) {
            BarView(width: Self.barWidth, color: color, value: core.usage)
            if core.frequency.currentHz > 0 {
                Text(ghzString(core.frequency.currentHz))
            }
            Text("\(Int(core.usage))%")
        }
        .font(.system(size: 9))
        .monospacedDigit()
        .lineLimit(1)
        .frame(width: Self.barWidth)
    }
}
