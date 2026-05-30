import SwiftUI

struct NetworkDetailView: View {
    static let panelTitle = "Network"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            DetailChart(lines: networkChartLines, maxValue: networkChartMax)
            DetailMetricSection(rows: [
                ("↓ In", monitor.networkInText),
                ("↑ Out", monitor.networkOutText),
                ("Total", monitor.networkTotalText),
            ])
            if monitor.hasWiFi {
                DetailMetricSection(title: "Wi-Fi", rows: availableDetailMetrics([
                    ("Signal", monitor.wifiSignalText),
                    ("Noise", monitor.wifiNoiseText),
                    ("Link Rate", monitor.wifiLinkRateText),
                    ("Channel", monitor.wifiChannelText),
                ]))
            }
            if monitor.hasConnectionCounts {
                DetailMetricSection(title: "Connections", rows: availableDetailMetrics([
                    ("TCP", monitor.tcpConnectionCountText),
                    ("UDP", monitor.udpConnectionCountText),
                ]))
            }
            DetailListSection(
                "Interfaces",
                data: Array(monitor.activeNetworkInterfaces.prefix(4).enumerated()),
                id: \.element.name
            ) { entry in
                statRow(verbatim: entry.element.displayName, value: monitor.formatNetworkInterface(entry.element))
            }
            DetailListSection(
                "Top Processes",
                data: Array(monitor.topNetworkProcesses.enumerated()),
                id: \.offset
            ) { entry in
                statRow(
                    verbatim: entry.element.name,
                    value: "↓\(monitor.formatProcessNetwork(entry.element.networkInBPS)) ↑\(monitor.formatProcessNetwork(entry.element.networkOutBPS))"
                )
            }
        }
    }

    private var networkChartLines: [ChartSeries] {
        [
            ChartSeries(history: monitor.paddedNetworkInHistory, color: .green),
            ChartSeries(history: monitor.paddedNetworkOutHistory, color: .red),
        ]
    }

    private var networkChartMax: Double {
        max((monitor.paddedNetworkInHistory + monitor.paddedNetworkOutHistory).max() ?? 1, 1_048_576)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    NetworkDetailView(monitor: SystemMonitor(settings: AppSettings()).start())
}
