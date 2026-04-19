import SwiftUI

struct CPUCoreChartsView: View {
    let settings: AppSettings
    var monitor: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(columns: mainWindowChartColumns, spacing: 8) {
                    ForEach(Array(monitor.paddedCPUPerCoreHistories.enumerated()), id: \.offset) { index, history in
                        MetricChartCard(
                            title: "Core \(index + 1)",
                            value: coreValue(for: index),
                            statusColor: progressColor(currentCoreUsage(for: index) / 100),
                            lines: [(history: history, color: coreColor(for: index))],
                            maxValue: 100
                        )
                    }
                }

                TopProcessesTable(settings: settings, monitor: monitor, initialSort: .cpu)
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func coreColor(for index: Int) -> Color {
        guard let pCount = monitor.cpuCoreFrequencies.pCoreCount else { return .blue }
        return index < pCount ? .blue : .green
    }

    private func currentCoreUsage(for index: Int) -> Double {
        guard monitor.cpuPerCore.indices.contains(index) else { return 0 }
        return monitor.cpuPerCore[index]
    }

    private func coreValue(for index: Int) -> String {
        String(format: "%.1f%%", currentCoreUsage(for: index))
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let settings = AppSettings()
    let monitor = SystemMonitor(settings: settings).start()
    CPUCoreChartsView(settings: settings, monitor: monitor)
        .frame(width: 700, height: 520)
}
