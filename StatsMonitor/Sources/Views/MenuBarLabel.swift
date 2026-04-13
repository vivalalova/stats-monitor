import SwiftUI

struct MenuBarLabel: View {
    var viewModel: StatsViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
            Text(viewModel.cpuPercent)
                .monospacedDigit()
        }
    }
}
