import SwiftUI

struct BatteryDetailView: View {
    static let panelTitle = "Battery"

    var viewModel: StatsViewModel

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            if viewModel.batteryHistory.count >= 2 {
                LineChartView(lines: [(viewModel.batteryHistory, .green)], maxValue: 100)
            }

            statRow("Charge", value: viewModel.batteryPercent)
            statRow("Status", value: viewModel.batteryStatus)
            statRow("Time", value: viewModel.batteryTimeRemaining)
            statRow("Health", value: viewModel.batteryHealth)
            statRow("Cycles", value: viewModel.batteryCycles)
            statRow("Max Capacity", value: viewModel.batteryMaxCapacity)
            statRow("Design Capacity", value: viewModel.batteryDesignCapacity)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    BatteryDetailView(viewModel: StatsViewModel())
}
