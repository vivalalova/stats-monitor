import SwiftUI

struct CPUMenuBarLabel: View {
    var viewModel: StatsViewModel
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
            Text(viewModel.cpuPercent).monospacedDigit()
        }
        .frame(width: 80)
    }
}

struct GPUMenuBarLabel: View {
    var viewModel: StatsViewModel
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "display")
            Text(viewModel.gpuPercent).monospacedDigit()
        }
        .frame(width: 80)
    }
}

struct MemoryMenuBarLabel: View {
    var viewModel: StatsViewModel
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "memorychip")
            Text(viewModel.memoryPercent).monospacedDigit()
        }
        .frame(width: 80)
    }
}

struct DiskMenuBarLabel: View {
    var viewModel: StatsViewModel
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "internaldrive")
            Text(viewModel.diskPercent).monospacedDigit()
        }
        .frame(width: 80)
    }
}

struct NetworkMenuBarLabel: View {
    var viewModel: StatsViewModel
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "network")
            Text("↓\(viewModel.networkIn)").monospacedDigit()
        }
        .frame(width: 100)
    }
}
