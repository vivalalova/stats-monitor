import SwiftUI

struct PowerDetailView: View {
    static let panelTitle = "Power"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            DetailChart(lines: monitor.hasPower ? [(monitor.paddedPowerHistory, .red)] : [])
            DetailMetricSection(rows: availableDetailMetrics([
                ("Total", monitor.powerText),
                ("CPU", monitor.cpuPowerText),
                ("GPU", monitor.gpuPowerText),
                ("Neural Engine", monitor.anePowerText),
            ]))
            DetailMetricSection(title: "Battery", rows: availableDetailMetrics([
                ("Charge", monitor.batteryPercent),
                ("Status", monitor.batteryStatusText),
                ("Time", monitor.batteryTimeRemainingText),
                ("Health", monitor.batteryHealthText),
                ("Cycles", monitor.batteryCyclesText),
                ("Max Capacity", monitor.batteryMaxCapacityText),
                ("Design Capacity", monitor.batteryDesignCapacityText),
            ]))
            DetailMetricSection(title: "Thermals", rows: availableDetailMetrics([
                ("CPU Temp", monitor.cpuTempText),
                ("GPU Temp", monitor.gpuTempText),
                ("Fans", monitor.fansSummaryText),
            ]))
            DetailListSection(
                "Top Energy Impact (score)",
                data: Array(monitor.topPowerProcesses.enumerated()),
                id: \.offset
            ) { entry in
                statRow(verbatim: entry.element.name, value: monitor.formatProcessPower(entry.element))
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    PowerDetailView(monitor: SystemMonitor(settings: AppSettings()).start())
}
