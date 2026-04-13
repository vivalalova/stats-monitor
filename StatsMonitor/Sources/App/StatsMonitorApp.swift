import SwiftUI

@main
struct StatsMonitorApp: App {
    @State private var viewModel = StatsViewModel()

    var body: some Scene {
        MenuBarExtra {
            StatsDetailView(viewModel: viewModel)
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
