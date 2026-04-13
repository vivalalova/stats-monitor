import SwiftUI

@main
struct StatsMonitorApp: App {
    @State private var viewModel = StatsViewModel()

    // macOS 加入順序是右→左，反向宣告讓顯示順序為 CPU/GPU/Memory/Disk/Network
    var body: some Scene {
        MenuBarExtra {
            NetworkDetailView(viewModel: viewModel)
        } label: {
            NetworkMenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra {
            DiskDetailView(viewModel: viewModel)
        } label: {
            DiskMenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra {
            MemoryDetailView(viewModel: viewModel)
        } label: {
            MemoryMenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra {
            GPUDetailView(viewModel: viewModel)
        } label: {
            GPUMenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra {
            CPUDetailView(viewModel: viewModel)
        } label: {
            CPUMenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
