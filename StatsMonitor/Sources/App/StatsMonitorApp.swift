import SwiftUI

@main
struct StatsMonitorApp: App {
    @State private var viewModel = StatsViewModel()

    // macOS 加入順序是右→左，反向宣告讓顯示順序為 CPU/GPU/Memory/Disk/Network
    var body: some Scene {
        @Bindable var s = viewModel.settings

        MenuBarExtra(isInserted: $s.showNetwork) {
            NetworkDetailView(viewModel: viewModel)
                .environment(viewModel.settings)
                .environment(viewModel)
        } label: {
            MenuBarItemLabel(icon: "network", text: "↓\(viewModel.networkIn)", width: 100)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra(isInserted: $s.showDisk) {
            DiskDetailView(viewModel: viewModel)
                .environment(viewModel.settings)
                .environment(viewModel)
        } label: {
            MenuBarItemLabel(icon: "internaldrive", text: viewModel.diskPercent)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra(isInserted: $s.showMemory) {
            MemoryDetailView(viewModel: viewModel)
                .environment(viewModel.settings)
                .environment(viewModel)
        } label: {
            MenuBarItemLabel(icon: "memorychip", text: viewModel.memoryPercent)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra(isInserted: $s.showGPU) {
            GPUDetailView(viewModel: viewModel)
                .environment(viewModel.settings)
                .environment(viewModel)
        } label: {
            MenuBarItemLabel(icon: "display", text: viewModel.gpuPercent)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra(isInserted: $s.showCPU) {
            CPUDetailView(viewModel: viewModel)
                .environment(viewModel.settings)
                .environment(viewModel)
        } label: {
            MenuBarItemLabel(icon: "cpu", text: viewModel.cpuPercent)
        }
        .menuBarExtraStyle(.window)
    }
}
