import SwiftUI

struct PowerDetailView: View {
    static let panelTitle = "Power"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            if monitor.paddedPowerHistory.count >= 2 {
                LineChartView(lines: [(monitor.paddedPowerHistory, .red)])
            }

            statRow("Total", value: monitor.powerText)
            statRow("CPU", value: monitor.cpuPowerText)
            statRow("GPU", value: monitor.gpuPowerText)
            statRow("Neural Engine", value: monitor.anePowerText)
            sectionHeader("Thermals")
            statRow("CPU Temp", value: monitor.cpuTempText)
            statRow("GPU Temp", value: monitor.gpuTempText)
            statRow("Fans", value: monitor.fansSummaryText)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    PowerDetailView(monitor: SystemMonitor(settings: AppSettings()))
}
