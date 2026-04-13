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
                let parts = viewModel.memoryLabelText.components(separatedBy: "/")
                Text(parts.first ?? "").monospacedDigit()
                Text(parts.last ?? "").monospacedDigit()
            }
            .font(.system(size: 9, weight: .medium))
            .fixedSize()
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
            .fixedSize()
        }
    }
}
