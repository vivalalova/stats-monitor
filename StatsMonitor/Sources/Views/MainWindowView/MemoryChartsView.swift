import SwiftUI

struct MemoryChartsView: View {
    let settings: AppSettings
    var monitor: SystemMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(
                    columns: MainWindowMetricGridLayout.columns(for: settings.dashboardColumns),
                    spacing: MainWindowMetricGridLayout.spacing
                ) {
                    MetricChartCard(
                        title: "Used",
                        value: monitor.memoryPercent,
                        statusColor: progressColor(monitor.memoryFraction),
                        lines: [(history: monitor.paddedMemoryHistory, color: .cyan)],
                        maxValue: 100
                    )
                    MetricChartCard(
                        title: "Free",
                        value: monitor.memoryFreeText,
                        statusColor: progressColor(1 - freeMemoryFraction),
                        lines: [(history: monitor.paddedMemoryFreeHistory, color: .green)],
                        maxValue: monitor.memoryChartMaxBytes
                    )
                    memoryBytesCard(
                        title: "Active",
                        value: monitor.memoryActiveText,
                        history: monitor.paddedMemoryActiveHistory,
                        color: .blue
                    )
                    memoryBytesCard(
                        title: "Wired",
                        value: monitor.memoryWiredText,
                        history: monitor.paddedMemoryWiredHistory,
                        color: .orange
                    )
                    memoryBytesCard(
                        title: "Compressed",
                        value: monitor.memoryCompressedText,
                        history: monitor.paddedMemoryCompressedHistory,
                        color: .purple
                    )
                    if showsSwapCard {
                        MetricChartCard(
                            title: "Swap Used",
                            value: monitor.memorySwapUsedText.isEmpty ? "0 B" : monitor.memorySwapUsedText,
                            statusColor: progressColor(memorySwapFraction),
                            lines: [(history: monitor.paddedMemorySwapHistory, color: .pink)],
                            maxValue: monitor.memorySwapChartMaxBytes
                        )
                    }
                }

                TopProcessesTable(settings: settings, monitor: monitor, initialSort: .memory)
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var freeMemoryFraction: Double {
        guard monitor.memoryChartMaxBytes > 0 else { return 0 }
        return (monitor.paddedMemoryFreeHistory.last ?? 0) / monitor.memoryChartMaxBytes
    }

    private var memorySwapFraction: Double {
        guard monitor.memorySwapChartMaxBytes > 0 else { return 0 }
        return (monitor.paddedMemorySwapHistory.last ?? 0) / monitor.memorySwapChartMaxBytes
    }

    private var showsSwapCard: Bool {
        monitor.paddedMemorySwapHistory.contains { $0 > 0 } || !monitor.memorySwapSummaryText.isEmpty
    }

    private func memoryBytesCard(
        title: String,
        value: String,
        history: [Double],
        color: Color
    ) -> some View {
        MetricChartCard(
            title: title,
            value: value,
            statusColor: progressColor((history.last ?? 0) / monitor.memoryChartMaxBytes),
            lines: [(history: history, color: color)],
            maxValue: monitor.memoryChartMaxBytes
        )
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let settings = AppSettings()
    let monitor = SystemMonitor(settings: settings).start()
    MemoryChartsView(settings: settings, monitor: monitor)
        .frame(width: 700, height: 520)
}
