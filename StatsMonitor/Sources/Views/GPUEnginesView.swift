import SwiftUI

struct GPUEnginesView: View {
    var monitor: SystemMonitor

    private let columns = [
        GridItem(.adaptive(minimum: 180), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
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
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func engineValue(_ name: String) -> String {
        String(format: "%.1f%%", monitor.gpuEngines[name] ?? 0)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    GPUEnginesView(monitor: SystemMonitor(settings: AppSettings()).start())
}
