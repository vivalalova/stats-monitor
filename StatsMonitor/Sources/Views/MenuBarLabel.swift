import SwiftUI

struct CPUMenuBarLabel: View {
    var viewModel: StatsViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
            Text(viewModel.cpuPercent)
                .monospacedDigit()
        }
    }
}

struct GPUMenuBarLabel: View {
    var viewModel: StatsViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "gpu")
            Text(viewModel.gpuPercent)
                .monospacedDigit()
        }
    }
}

struct MemoryMenuBarLabel: View {
    var viewModel: StatsViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "memorychip")
            Text(viewModel.memoryLabelText)
                .monospacedDigit()
        }
    }
}

struct DiskMenuBarLabel: View {
    var viewModel: StatsViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "internaldrive")
            Text(viewModel.diskPercent)
                .monospacedDigit()
        }
    }
}

struct NetworkMenuBarLabel: View {
    var viewModel: StatsViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "network")
            Text("↓\(viewModel.networkIn) ↑\(viewModel.networkOut)")
                .monospacedDigit()
        }
    }
}
