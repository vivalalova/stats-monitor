import SwiftUI

struct CPUDetailView: View {
    var viewModel: StatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CPU")
                    .font(.headline)
                statRow("User",   value: viewModel.cpuUserPercent)
                statRow("System", value: viewModel.cpuSystemPercent)
                statRow("Idle",   value: String(format: "%.1f%%", viewModel.monitor.stats.cpu.idle))
                ProgressView(value: viewModel.monitor.stats.cpu.used / 100)
                    .tint(progressColor(viewModel.monitor.stats.cpu.used / 100))
            }

            Divider()

            quitButton()
        }
        .padding(16)
        .frame(width: 240)
    }
}

struct GPUDetailView: View {
    var viewModel: StatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("GPU")
                    .font(.headline)
                statRow("Device",   value: viewModel.gpuPercent)
                statRow("Renderer", value: viewModel.gpuRenderPercent)
                ProgressView(value: viewModel.monitor.stats.gpu.used / 100)
                    .tint(progressColor(viewModel.monitor.stats.gpu.used / 100))
            }

            Divider()

            quitButton()
        }
        .padding(16)
        .frame(width: 240)
    }
}

struct MemoryDetailView: View {
    var viewModel: StatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Memory")
                    .font(.headline)
                statRow("Active",     value: viewModel.memoryActive)
                statRow("Wired",      value: viewModel.memoryWired)
                statRow("Compressed", value: viewModel.memoryCompressed)
                ProgressView(value: viewModel.monitor.stats.memory.usedFraction)
                    .tint(progressColor(viewModel.monitor.stats.memory.usedFraction))
            }

            Divider()

            quitButton()
        }
        .padding(16)
        .frame(width: 240)
    }
}

struct DiskDetailView: View {
    var viewModel: StatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Disk")
                    .font(.headline)
                statRow("Used",  value: viewModel.diskUsed)
                statRow("Free",  value: viewModel.diskFree)
                statRow("Total", value: viewModel.diskTotal)
                ProgressView(value: viewModel.monitor.stats.disk.usedFraction)
                    .tint(progressColor(viewModel.monitor.stats.disk.usedFraction))
            }

            Divider()

            quitButton()
        }
        .padding(16)
        .frame(width: 240)
    }
}

struct NetworkDetailView: View {
    var viewModel: StatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Network")
                    .font(.headline)
                statRow("↓ In",  value: viewModel.networkIn)
                statRow("↑ Out", value: viewModel.networkOut)
            }

            Divider()

            quitButton()
        }
        .padding(16)
        .frame(width: 240)
    }
}

// MARK: - Shared helpers

private func statRow(_ label: String, value: String) -> some View {
    HStack {
        Text(label)
            .foregroundStyle(.secondary)
        Spacer()
        Text(value)
            .monospacedDigit()
            .fontWeight(.medium)
    }
    .font(.system(size: 13))
}

private func progressColor(_ fraction: Double) -> Color {
    switch fraction {
    case ..<0.6:  .green
    case ..<0.8:  .orange
    default:      .red
    }
}

@MainActor
private func quitButton() -> some View {
    Button("Quit StatsMonitor") {
        NSApplication.shared.terminate(nil)
    }
    .buttonStyle(.plain)
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity, alignment: .center)
}
