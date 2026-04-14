import SwiftUI

// MARK: - DashboardView

struct DashboardView: View {
    var viewModel: StatsViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        let networkMax = max(viewModel.networkInHistory.max() ?? 0,
                             viewModel.networkOutHistory.max() ?? 0,
                             1)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: columns, spacing: 12) {
                    MetricCard(
                        title: "CPU",
                        value: viewModel.cpuPercent,
                        statusColor: progressColor(viewModel.cpuFraction),
                        lines: [(history: viewModel.cpuHistory, color: .blue)],
                        maxValue: 100
                    )
                    MetricCard(
                        title: "GPU",
                        value: viewModel.gpuPercent,
                        statusColor: progressColor(viewModel.gpuFraction),
                        lines: [(history: viewModel.gpuHistory, color: .purple)],
                        maxValue: 100
                    )
                    MetricCard(
                        title: "Memory",
                        value: viewModel.memoryPercent,
                        statusColor: progressColor(viewModel.memoryFraction),
                        lines: [(history: viewModel.memoryHistory, color: .cyan)],
                        maxValue: 100
                    )
                    MetricCard(
                        title: "Disk",
                        value: viewModel.diskPercent,
                        statusColor: progressColor(viewModel.diskFraction),
                        lines: [(history: viewModel.diskHistory, color: .indigo)],
                        maxValue: 100
                    )
                    MetricCard(
                        title: "Network",
                        value: "↓\(viewModel.networkIn)  ↑\(viewModel.networkOut)",
                        statusColor: .blue,
                        lines: [
                            (history: viewModel.networkInHistory,  color: .blue),
                            (history: viewModel.networkOutHistory, color: .green),
                        ],
                        maxValue: networkMax
                    )
                }

                DashboardProcessTable(viewModel: viewModel)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - MetricCard

private struct MetricCard: View {
    let title: String
    let value: String
    let statusColor: Color
    let lines: [(history: [Double], color: Color)]
    let maxValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            LineChartView(lines: lines, maxValue: maxValue, height: 60)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - DashboardProcessTable

private struct DashboardProcessTable: View {
    var viewModel: StatsViewModel

    private var mergedProcesses: [ProcInfo] {
        var byName: [String: ProcInfo] = [:]
        let all = viewModel.topCPUProcesses
            + viewModel.topMemoryProcesses
            + viewModel.topDiskProcesses
            + viewModel.topNetworkProcesses
        for proc in all {
            if let existing = byName[proc.name] {
                byName[proc.name] = ProcInfo(
                    name:          proc.name,
                    cpuPercent:    max(existing.cpuPercent,    proc.cpuPercent),
                    memoryBytes:   max(existing.memoryBytes,   proc.memoryBytes),
                    diskReadBPS:   max(existing.diskReadBPS,   proc.diskReadBPS),
                    diskWriteBPS:  max(existing.diskWriteBPS,  proc.diskWriteBPS),
                    networkInBPS:  max(existing.networkInBPS,  proc.networkInBPS),
                    networkOutBPS: max(existing.networkOutBPS, proc.networkOutBPS)
                )
            } else {
                byName[proc.name] = proc
            }
        }
        return byName.values.sorted {
            if $0.cpuPercent != $1.cpuPercent { return $0.cpuPercent > $1.cpuPercent }
            if $0.memoryBytes != $1.memoryBytes { return $0.memoryBytes > $1.memoryBytes }
            return $0.name < $1.name
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Processes")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(spacing: 0) {
                HStack {
                    Text("Name")
                    Spacer()
                    Text("CPU%")    .frame(width: 60, alignment: .trailing)
                    Text("Memory")  .frame(width: 72, alignment: .trailing)
                    Text("Disk")    .frame(width: 72, alignment: .trailing)
                    Text("Network") .frame(width: 80, alignment: .trailing)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)

                Divider()

                ForEach(
                    Array(mergedProcesses.prefix(viewModel.settings.processCount)),
                    id: \.name
                ) { proc in
                    HStack {
                        Text(proc.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(viewModel.formatProcessCPU(proc.cpuPercent))
                            .frame(width: 60, alignment: .trailing)
                        Text(viewModel.formatProcessMemory(proc.memoryBytes))
                            .frame(width: 72, alignment: .trailing)
                        Text(proc.diskTotalBPS > 0
                             ? viewModel.formatProcessDisk(proc.diskTotalBPS) : "—")
                            .frame(width: 72, alignment: .trailing)
                        Text(proc.networkTotalBPS > 0
                             ? viewModel.formatProcessNetwork(proc.networkTotalBPS) : "—")
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    DashboardView(viewModel: StatsViewModel())
        .frame(width: 820, height: 520)
}
