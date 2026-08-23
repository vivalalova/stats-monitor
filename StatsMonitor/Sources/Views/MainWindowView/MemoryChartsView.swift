import SwiftUI

struct MemoryChartsView: View {
    let settings: AppSettings
    var monitor: SystemMonitor

    var body: some View {
        MetricGridPage(
            columns: MainWindowMetricGridLayout.columns(for: settings.dashboardColumns),
            gridSpacing: MainWindowMetricGridLayout.spacing
        ) {
            MetricChartCard(
                title: "Used",
                value: monitor.memoryPercent,
                status: MetricStatus(fraction: monitor.memoryFraction),
                lines: [ChartSeries(history: monitor.paddedMemoryHistory, color: .cyan)],
                maxValue: 100
            )
            // 「可用」是反向指標：正常／偏高／過高 套上去字面與含義相反，
            // 而記憶體壓力已由上面的「已用」卡呈現，這裡不重複給狀態。
            MetricChartCard(
                title: "Free",
                value: monitor.memoryFreeText,
                lines: [ChartSeries(history: monitor.paddedMemoryFreeHistory, color: .green)],
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
                    status: MetricStatus(fraction: memorySwapFraction),
                    lines: [ChartSeries(history: monitor.paddedMemorySwapHistory, color: .pink)],
                    maxValue: monitor.memorySwapChartMaxBytes
                )
            }
            if showsPagingCard {
                MetricChartCard(
                    title: "Page I/O",
                    value: monitor.memoryPagingSummaryText,
                    lines: [
                        ChartSeries(history: monitor.paddedMemoryPageInHistory, color: .teal),
                        ChartSeries(history: monitor.paddedMemoryPageOutHistory, color: .orange),
                    ],
                    maxValue: monitor.memoryPagingChartMaxBytes
                )
            }
        } footer: {
            TopProcessesTable(settings: settings, monitor: monitor, initialSort: .memory)
        }
    }

    private var memorySwapFraction: Double {
        guard monitor.memorySwapChartMaxBytes > 0 else { return 0 }
        return (monitor.paddedMemorySwapHistory.last ?? 0) / monitor.memorySwapChartMaxBytes
    }

    private var showsSwapCard: Bool {
        monitor.paddedMemorySwapHistory.contains { $0 > 0 } || !monitor.memorySwapSummaryText.isEmpty
    }

    private var showsPagingCard: Bool {
        monitor.hasMemoryPaging
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
            status: MetricStatus(fraction: (history.last ?? 0) / monitor.memoryChartMaxBytes),
            lines: [ChartSeries(history: history, color: color)],
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
