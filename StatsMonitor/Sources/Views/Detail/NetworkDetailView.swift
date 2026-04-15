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

            if !monitor.topNetworkProcesses.isEmpty {
                sectionHeader("Top Processes")
                ForEach(Array(monitor.topNetworkProcesses.enumerated()), id: \.offset) { _, proc in
                    statRow(verbatim: proc.name, value: "↓\(monitor.formatProcessNetwork(proc.networkInBPS)) ↑\(monitor.formatProcessNetwork(proc.networkOutBPS))")
                }
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    NetworkDetailView(monitor: SystemMonitor(settings: AppSettings()))
}
