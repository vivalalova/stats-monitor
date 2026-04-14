import SwiftUI

@main
struct StatsMonitorApp: App {
    @State private var viewModel = StatsViewModel()

    var body: some Scene {
        MenuBarExtra {
            StatsMenuView(viewModel: viewModel)
        } label: {
            StatsMenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
