import SwiftUI

struct BatteryDetailView: View {
    static let panelTitle = "Battery"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            DetailChart(lines: [(monitor.paddedBatteryHistory, .green)], maxValue: 100)
            DetailMetricSection(rows: [
                ("Charge", monitor.batteryPercent),
                ("Status", monitor.batteryStatusText),
                ("Time", monitor.batteryTimeRemainingText),
                ("Health", monitor.batteryHealthText),
                ("Cycles", monitor.batteryCyclesText),
                ("Max Capacity", monitor.batteryMaxCapacityText),
                ("Design Capacity", monitor.batteryDesignCapacityText),
            ])
            DetailMetricSection(title: "System", rows: [
                ("Temperature", monitor.cpuTempText),
                ("Power Draw", monitor.powerText),
            ])
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    BatteryDetailView(monitor: SystemMonitor(settings: AppSettings()))
}
