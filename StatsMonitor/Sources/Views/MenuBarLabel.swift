import SwiftUI

struct CPUMenuBarLabel: View {
    var viewModel: StatsViewModel
    var body: some View {
        Text(viewModel.cpuPercent)
            .monospacedDigit()
            .frame(width: 52)
    }
}

struct GPUMenuBarLabel: View {
    var viewModel: StatsViewModel
    var body: some View {
        Text(viewModel.gpuPercent)
            .monospacedDigit()
            .frame(width: 52)
    }
}

struct MemoryMenuBarLabel: View {
    var viewModel: StatsViewModel
    var body: some View {
        Text(viewModel.memoryPercent)
            .monospacedDigit()
            .frame(width: 52)
    }
}

struct DiskMenuBarLabel: View {
    var viewModel: StatsViewModel
    var body: some View {
        Text(viewModel.diskPercent)
            .monospacedDigit()
            .frame(width: 52)
    }
}

struct NetworkMenuBarLabel: View {
    var viewModel: StatsViewModel
    var body: some View {
        Text("↓\(viewModel.networkIn)")
            .monospacedDigit()
            .frame(width: 80)
    }
}
