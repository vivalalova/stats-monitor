import SwiftUI

struct PowerDetailView: View {
    static let panelTitle = "Power"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            DetailChart(lines: [(monitor.paddedPowerHistory, .red)])
            DetailMetricSection(rows: [
                ("Total", monitor.powerText),
                ("CPU", monitor.cpuPowerText),
                ("GPU", monitor.gpuPowerText),
                ("Neural Engine", monitor.anePowerText),
            ])
            DetailMetricSection(title: "Thermals", rows: [
                ("CPU Temp", monitor.cpuTempText),
                ("GPU Temp", monitor.gpuTempText),
                ("Fans", monitor.fansSummaryText),
            ])
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    PowerDetailView(monitor: SystemMonitor(settings: AppSettings()).start())
}
