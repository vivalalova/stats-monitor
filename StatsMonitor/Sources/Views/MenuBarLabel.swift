import SwiftUI

struct MenuBarLabel: View {
    var viewModel: StatsViewModel

    var body: some View {
        Label {
            Text(viewModel.cpuPercent)
                .monospacedDigit()
        } icon: {
            Image(systemName: "cpu")
        }
    }
}
