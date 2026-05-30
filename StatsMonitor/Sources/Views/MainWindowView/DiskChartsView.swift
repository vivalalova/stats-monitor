import SwiftUI

struct DiskChartsView: View {
    let settings: AppSettings
    var monitor: SystemMonitor

    var body: some View {
        MetricGridPage(
            columns: MainWindowMetricGridLayout.columns(for: settings.dashboardColumns),
            gridSpacing: MainWindowMetricGridLayout.spacing
        ) {
            MetricChartCard(
                title: "Capacity",
                value: monitor.diskPercent,
                statusColor: progressColor(monitor.diskFraction),
                lines: [ChartSeries(history: monitor.paddedDiskHistory, color: .indigo)],
                maxValue: 100
            )
            MetricChartCard(
                title: "Read",
                value: monitor.diskReadText,
                statusColor: .teal,
                lines: [ChartSeries(history: monitor.paddedDiskReadHistory, color: .teal)],
                maxValue: throughputChartMax
            )
            MetricChartCard(
                title: "Write",
                value: monitor.diskWriteText,
                statusColor: .orange,
                lines: [ChartSeries(history: monitor.paddedDiskWriteHistory, color: .orange)],
                maxValue: throughputChartMax
            )
            MetricChartCard(
                title: "Total I/O",
                value: monitor.diskActivityText,
                statusColor: .blue,
                lines: [ChartSeries(history: monitor.paddedDiskActivityHistory, color: .blue)],
                maxValue: throughputChartMax
            )
        } footer: {
            TopProcessesTable(settings: settings, monitor: monitor, initialSort: .disk)
        }
    }

    private var throughputChartMax: Double {
        max(
            (
                monitor.paddedDiskReadHistory
                + monitor.paddedDiskWriteHistory
                + monitor.paddedDiskActivityHistory
            ).max() ?? 0,
            1_048_576
        )
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let settings = AppSettings()
    let monitor = SystemMonitor(settings: settings).start()
    DiskChartsView(settings: settings, monitor: monitor)
        .frame(width: 700, height: 520)
}
