import SwiftUI

struct StatsMenuBarLabel: View {
    var viewModel: StatsViewModel
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.fill")
            Text(viewModel.cpuPercent).monospacedDigit()
        }
    }
}
