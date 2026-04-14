import SwiftUI

@main
struct StatsMonitorApp: App {
    @State private var viewModel = StatsViewModel()

    // macOS 加入順序是右→左，反向宣告讓顯示順序為 CPU/GPU/Memory/Disk/Network
    var body: some Scene {
        MenuBarExtra {
            NetworkDetailView(viewModel: viewModel)
        } label: {
            MenuBarItemLabel(icon: "network", text: "↓\(viewModel.networkIn)", width: 100)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra {
            DiskDetailView(viewModel: viewModel)
        } label: {
            MenuBarItemLabel(icon: "internaldrive", text: viewModel.diskPercent)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra {
            MemoryDetailView(viewModel: viewModel)
        } label: {
            MenuBarItemLabel(icon: "memorychip", text: viewModel.memoryPercent)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra {
            GPUDetailView(viewModel: viewModel)
        } label: {
            MenuBarItemLabel(icon: "display", text: viewModel.gpuPercent)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra {
            CPUDetailView(viewModel: viewModel)
        } label: {
            MenuBarItemLabel(icon: "cpu", text: viewModel.cpuPercent)
        }
        .menuBarExtraStyle(.window)
    }
}
