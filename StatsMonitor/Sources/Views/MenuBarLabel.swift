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
            Image(systemName: "display")
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
            VStack(spacing: 0) {
                ForEach(viewModel.memoryLabelText.components(separatedBy: "/"), id: \.self) { part in
                    Text(part).monospacedDigit()
                }
            }
            .font(.system(size: 9, weight: .medium))
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
            VStack(spacing: 0) {
                Text("↓\(viewModel.networkIn)").monospacedDigit()
                Text("↑\(viewModel.networkOut)").monospacedDigit()
            }
            .font(.system(size: 9, weight: .medium))
        }
    }
}
