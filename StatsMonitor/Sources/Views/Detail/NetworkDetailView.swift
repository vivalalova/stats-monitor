import SwiftUI

struct NetworkDetailView: View {
    static let panelTitle = "Network"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            let maxVal = max(
                (monitor.paddedNetworkInHistory + monitor.paddedNetworkOutHistory).max() ?? 1,
                1_048_576
            )

            LineChartView(
                lines: [(monitor.paddedNetworkInHistory, .green), (monitor.paddedNetworkOutHistory, .red)],
                maxValue: maxVal
            )

            statRow("↓ In",  value: monitor.networkInText)
            statRow("↑ Out", value: monitor.networkOutText)
            statRow("Total", value: monitor.networkTotalText)
            sectionHeader("System")
            statRow("Temperature", value: monitor.cpuTempText)
            statRow("System Power", value: monitor.powerText)

            if !monitor.topNetworkProcesses.isEmpty {
                sectionHeader("Top Processes")
                compactRows(Array(monitor.topNetworkProcesses.enumerated()), id: \.offset) { entry in
                    statRow(
                        verbatim: entry.element.name,
                        value: "↓\(monitor.formatProcessNetwork(entry.element.networkInBPS)) ↑\(monitor.formatProcessNetwork(entry.element.networkOutBPS))"
                    )
                }
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    NetworkDetailView(monitor: SystemMonitor(settings: AppSettings()))
}
