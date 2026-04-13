import SwiftUI

struct StatsDetailView: View {
    var viewModel: StatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            statSection("CPU") {
                statRow("Used",   value: viewModel.cpuPercent)
                statRow("User",   value: viewModel.cpuUserPercent)
                statRow("System", value: viewModel.cpuSystemPercent)
                ProgressView(value: viewModel.monitor.stats.cpu.used / 100)
                    .tint(progressColor(viewModel.monitor.stats.cpu.used / 100))
            }

            statSection("Memory") {
                statRow("Used",  value: "\(viewModel.memoryUsed) / \(viewModel.memoryTotal)")
                statRow("Usage", value: viewModel.memoryPercent)
                ProgressView(value: viewModel.monitor.stats.memory.usedFraction)
                    .tint(progressColor(viewModel.monitor.stats.memory.usedFraction))
            }

            statSection("Disk") {
                statRow("Used",  value: "\(viewModel.diskUsed) / \(viewModel.diskTotal)")
                statRow("Usage", value: viewModel.diskPercent)
                ProgressView(value: viewModel.monitor.stats.disk.usedFraction)
                    .tint(progressColor(viewModel.monitor.stats.disk.usedFraction))
            }

            statSection("Network") {
                statRow("↓ In",  value: viewModel.networkIn)
                statRow("↑ Out", value: viewModel.networkOut)
            }

            Divider()

            Button("Quit StatsMonitor") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .frame(width: 280)
    }

    @ViewBuilder
    private func statSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }

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
}
