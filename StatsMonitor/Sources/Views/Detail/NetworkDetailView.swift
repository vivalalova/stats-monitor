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

    private var networkChartLines: [(history: [Double], color: Color)] {
        [(monitor.paddedNetworkInHistory, .green), (monitor.paddedNetworkOutHistory, .red)]
    }

    private var networkChartMax: Double {
        max((monitor.paddedNetworkInHistory + monitor.paddedNetworkOutHistory).max() ?? 1, 1_048_576)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    NetworkDetailView(monitor: SystemMonitor(settings: AppSettings()).start())
}
