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
                lines: [networkInChartLine(monitor: monitor)],
                maxValue: throughputChartMax
            )
            MetricChartCard(
                title: "Out",
                value: monitor.networkOutText,
                lines: [networkOutChartLine(monitor: monitor)],
                maxValue: throughputChartMax
            )
            MetricChartCard(
                title: "Total",
                value: monitor.networkTotalText,
                lines: networkChartLines(monitor: monitor),
                legendLabels: NetworkChartLegend.labels,
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
