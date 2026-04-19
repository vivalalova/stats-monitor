import SwiftUI

struct NetworkChartsView: View {
    let settings: AppSettings
    var monitor: SystemMonitor

    var body: some View {
        MetricGridPage(
            columns: MainWindowMetricGridLayout.columns(for: settings.dashboardColumns),
            gridSpacing: MainWindowMetricGridLayout.spacing
        ) {
            MetricChartCard(
                title: "In",
                value: monitor.networkInText,
                statusColor: .green,
                lines: [(history: monitor.paddedNetworkInHistory, color: .green)],
                maxValue: throughputChartMax
            )
            MetricChartCard(
                title: "Out",
                value: monitor.networkOutText,
                statusColor: .red,
                lines: [(history: monitor.paddedNetworkOutHistory, color: .red)],
                maxValue: throughputChartMax
            )
            MetricChartCard(
                title: "Total",
                value: monitor.networkTotalText,
                statusColor: .blue,
                lines: [
                    (history: monitor.paddedNetworkInHistory,  color: .green),
                    (history: monitor.paddedNetworkOutHistory, color: .red),
                ],
                maxValue: throughputChartMax
            )
        } footer: {
            TopProcessesTable(settings: settings, monitor: monitor, initialSort: .network)
        }
    }

    private var throughputChartMax: Double {
        max(
            (monitor.paddedNetworkInHistory + monitor.paddedNetworkOutHistory).max() ?? 0,
            1_048_576
        )
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let settings = AppSettings()
    let monitor = SystemMonitor(settings: settings).start()
    NetworkChartsView(settings: settings, monitor: monitor)
        .frame(width: 700, height: 520)
}
