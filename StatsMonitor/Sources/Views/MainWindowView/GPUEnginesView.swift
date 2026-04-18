import SwiftUI

struct GPUEnginesView: View {
    let settings: AppSettings
    var monitor: SystemMonitor

    private let columns = [
        GridItem(.adaptive(minimum: 180), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(columns: columns, spacing: 8) {
                    if monitor.hasGPUFrequency {
                        MetricChartCard(
                            title: "Frequency",
                            value: monitor.gpuFrequencyText,
                            statusColor: .orange,
                            lines: [(history: monitor.paddedGPUFrequencyHistory, color: .orange)],
                            maxValue: max(monitor.gpuFrequencyMaxHz, 1)
                        )
                    }
                    if monitor.hasMediaEngine {
                        MetricChartCard(
                            title: "Media Engine",
                            value: monitor.gpuMediaEnginePowerText,
                            statusColor: .red,
                            lines: [(history: monitor.paddedGPUMediaEngineHistory, color: .red)],
                            maxValue: max(monitor.paddedGPUMediaEngineHistory.max() ?? 0, 0.5)
                        )
                    }
                    ForEach(Array(monitor.paddedGPUEngineHistories.enumerated()), id: \.offset) { _, entry in
                        MetricChartCard(
                            title: entry.name,
                            value: engineValue(entry.name),
                            statusColor: progressColor((monitor.gpuEngines[entry.name] ?? 0) / 100),
                            lines: [(history: entry.history, color: .purple)],
                            maxValue: 100
                        )
                    }
                }

                TopProcessesTable(settings: settings, monitor: monitor, initialSort: .gpu)
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func engineValue(_ name: String) -> String {
        String(format: "%.1f%%", monitor.gpuEngines[name] ?? 0)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let settings = AppSettings()
    let monitor = SystemMonitor(settings: settings).start()
    GPUEnginesView(settings: settings, monitor: monitor)
        .frame(width: 700, height: 520)
}
