import SwiftUI

struct BatteryDetailView: View {
    static let panelTitle = "Battery"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            if monitor.paddedBatteryHistory.count >= 2 {
                LineChartView(lines: [(monitor.paddedBatteryHistory, .green)], maxValue: 100)
            }

            statRow("Charge", value: monitor.batteryPercent)
            statRow("Status", value: monitor.batteryStatusText)
            statRow("Time", value: monitor.batteryTimeRemainingText)
            statRow("Health", value: monitor.batteryHealthText)
            statRow("Cycles", value: monitor.batteryCyclesText)
            statRow("Max Capacity", value: monitor.batteryMaxCapacityText)
            statRow("Design Capacity", value: monitor.batteryDesignCapacityText)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    BatteryDetailView(monitor: SystemMonitor(settings: AppSettings()))
}
