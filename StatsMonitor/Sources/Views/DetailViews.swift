import SwiftUI

// MARK: - Panel exclusion

extension Notification.Name {
    static let panelOpened = Notification.Name("StatsMonitorPanelOpened")
}

enum PanelID: String {
    case cpu, gpu, memory, disk, network

    var title: String {
        switch self {
        case .cpu:     "CPU"
        case .gpu:     "GPU"
        case .memory:  "Memory"
        case .disk:    "Disk"
        case .network: "Network"
        }
    }
}

private struct DetailPanel<Content: View>: View {
    let id: PanelID
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailToolbar(id.title)
            content()
        }
        .padding(16)
        .frame(width: 280)
        .onAppear { NotificationCenter.default.post(name: .panelOpened, object: id.rawValue) }
        .onReceive(NotificationCenter.default.publisher(for: .panelOpened)) { note in
            if note.object as? String != id.rawValue { dismiss() }
        }
    }
}

// MARK: - CPU Detail

struct CPUDetailView: View {
    var viewModel: StatsViewModel

    var body: some View {
        DetailPanel(id: .cpu) {
            if viewModel.cpuHistory.count >= 2 {
                LineChartView(lines: [(viewModel.cpuHistory, .blue)])
            }

            statRow("Used",   value: viewModel.cpuPercent)
            statRow("User",   value: viewModel.cpuUserPercent)
            statRow("System", value: viewModel.cpuSystemPercent)
            statRow("Idle",   value: String(format: "%.1f%%", viewModel.monitor.stats.cpu.idle))
            ProgressView(value: viewModel.monitor.stats.cpu.used / 100)
                .tint(progressColor(viewModel.monitor.stats.cpu.used / 100))

            if !viewModel.cpuPerCore.isEmpty {
                sectionHeader("Per Core")
                CoreGridView(cores: viewModel.cpuPerCore,
                             frequencies: viewModel.cpuCoreFrequencies)
            }

            if !viewModel.topCPUProcesses.isEmpty {
                sectionHeader("Top Processes")
                ForEach(Array(viewModel.topCPUProcesses.enumerated()), id: \.offset) { _, proc in
                    statRow(proc.name, value: viewModel.formatProcessCPU(proc.cpuPercent))
                }
            }
        }
    }
}

// MARK: - GPU Detail

struct GPUDetailView: View {
    var viewModel: StatsViewModel

    var body: some View {
        DetailPanel(id: .gpu) {
            if viewModel.gpuHistory.count >= 2 {
                LineChartView(lines: [(viewModel.gpuHistory, .purple)])
            }

            statRow("Device",   value: viewModel.gpuPercent)
            statRow("Renderer", value: viewModel.gpuRenderPercent)
            if viewModel.gpuVramUsed > 0 {
                statRow("GPU Mem", value: viewModel.gpuVramUsedStr)
            }
            if viewModel.anePowerMilliWatts > 0 {
                statRow("Neural Engine", value: viewModel.anePowerStr)
            }
            ProgressView(value: viewModel.monitor.stats.gpu.used / 100)
                .tint(progressColor(viewModel.monitor.stats.gpu.used / 100))

            if !viewModel.gpuEngines.isEmpty {
                sectionHeader("Engines")
                EngineGridView(engines: viewModel.gpuEngines)
            }
        }
    }
}

// MARK: - Memory Detail

struct MemoryDetailView: View {
    var viewModel: StatsViewModel

    var body: some View {
        DetailPanel(id: .memory) {
            if viewModel.memoryHistory.count >= 2 {
                LineChartView(lines: [(viewModel.memoryHistory, .orange)])
            }

            statRow("Used",       value: "\(viewModel.memoryUsed) / \(viewModel.memoryTotal)")
            statRow("Active",     value: viewModel.memoryActive)
            statRow("Wired",      value: viewModel.memoryWired)
            statRow("Compressed", value: viewModel.memoryCompressed)
            ProgressView(value: viewModel.monitor.stats.memory.usedFraction)
                .tint(progressColor(viewModel.monitor.stats.memory.usedFraction))

            if !viewModel.topMemoryProcesses.isEmpty {
                sectionHeader("Top Processes")
                ForEach(Array(viewModel.topMemoryProcesses.enumerated()), id: \.offset) { _, proc in
                    statRow(proc.name, value: viewModel.formatProcessMemory(proc.memoryBytes))
                }
            }
        }
    }
}

// MARK: - Disk Detail

struct DiskDetailView: View {
    var viewModel: StatsViewModel

    var body: some View {
        DetailPanel(id: .disk) {
            let maxIO = max(
                (viewModel.diskReadHistory + viewModel.diskWriteHistory).max() ?? 1,
                1_048_576
            )

            LineChartView(
                lines: [(viewModel.diskReadHistory, .yellow), (viewModel.diskWriteHistory, .orange)],
                maxValue: maxIO
            )

            statRow("↓ Read",  value: viewModel.diskRead)
            statRow("↑ Write", value: viewModel.diskWrite)
            Divider()
            statRow("Used",  value: viewModel.diskUsed)
            statRow("Free",  value: viewModel.diskFree)
            statRow("Total", value: viewModel.diskTotal)
            ProgressView(value: viewModel.monitor.stats.disk.usedFraction)
                .tint(progressColor(viewModel.monitor.stats.disk.usedFraction))

            if !viewModel.topDiskProcesses.isEmpty {
                sectionHeader("Top Processes")
                ForEach(Array(viewModel.topDiskProcesses.enumerated()), id: \.offset) { _, proc in
                    statRow(proc.name, value: "↓\(viewModel.formatProcessDisk(proc.diskReadBPS)) ↑\(viewModel.formatProcessDisk(proc.diskWriteBPS))")
                }
            }
        }
    }
}

// MARK: - Network Detail

struct NetworkDetailView: View {
    var viewModel: StatsViewModel

    var body: some View {
        DetailPanel(id: .network) {
            let maxVal = max(
                (viewModel.networkInHistory + viewModel.networkOutHistory).max() ?? 1,
                1_048_576
            )

            LineChartView(
                lines: [(viewModel.networkInHistory, .green), (viewModel.networkOutHistory, .red)],
                maxValue: maxVal
            )

            statRow("↓ In",  value: viewModel.networkIn)
            statRow("↑ Out", value: viewModel.networkOut)

            if !viewModel.topNetworkProcesses.isEmpty {
                sectionHeader("Top Processes")
                ForEach(Array(viewModel.topNetworkProcesses.enumerated()), id: \.offset) { _, proc in
                    statRow(proc.name, value: "↓\(viewModel.formatProcessNetwork(proc.networkInBPS)) ↑\(viewModel.formatProcessNetwork(proc.networkOutBPS))")
                }
            }
        }
    }
}

// MARK: - Shared bar primitives

private enum BarMetrics {
    // frame width 280 – padding 16*2 = 248
    static let contentWidth: CGFloat = 248
    static let spacing: CGFloat      = 4
    static let height: CGFloat       = 48
}

private struct BarView: View {
    let width: CGFloat
    let color: Color
    let value: Double  // 0...100

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.primary.opacity(0.08))
                .frame(width: width, height: BarMetrics.height)
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: width, height: max(2, BarMetrics.height * value / 100))
        }
    }
}

// MARK: - Vertical core grid

private struct CoreGridView: View {
    var cores: [Double]
    var frequencies: [CPUCoreFrequency] = []

    // ≤10 cores → fill the full row; >10 → always use 10-column width
    private var effectiveColumns: Int { min(cores.count, 10) }

    private var barWidth: CGFloat {
        (BarMetrics.contentWidth - BarMetrics.spacing * CGFloat(effectiveColumns - 1)) / CGFloat(effectiveColumns)
    }

    private var rows: [[(index: Int, value: Double)]] {
        let items = cores.enumerated().map { (index: $0.offset, value: $0.element) }
        return stride(from: 0, to: items.count, by: effectiveColumns).map {
            Array(items[$0 ..< min($0 + effectiveColumns, items.count)])
        }
    }

    // P-cores (blue) come first in the frequencies array with higher maxHz;
    // E-cores (green) follow with lower maxHz.
    // Returns nil when cluster distinction is unavailable.
    private var pCoreCount: Int? {
        guard !frequencies.isEmpty else { return nil }
        let distinctMax = Set(frequencies.map(\.maxHz).filter { $0 > 0 })
        guard distinctMax.count >= 2, let highMax = distinctMax.max() else { return nil }
        return frequencies.prefix(while: { $0.maxHz == highMax }).count
    }

    private func barColor(for index: Int) -> Color {
        guard let pCount = pCoreCount else { return progressColor(cores[index] / 100) }
        return index < pCount ? .blue : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .bottom, spacing: BarMetrics.spacing) {
                    ForEach(row, id: \.index) { item in
                        let freq = item.index < frequencies.count ? frequencies[item.index] : .zero
                        VStack(spacing: 1) {
                            BarView(width: barWidth, color: barColor(for: item.index), value: item.value)
                            if freq.currentHz > 0 {
                                Text(ghzString(freq.currentHz))
                            }
                            Text("\(Int(item.value))%")
                        }
                        .font(.system(size: 9))
                        .monospacedDigit()
                    }
                }
            }
        }
    }

    private func ghzString(_ hz: UInt64) -> String {
        let ghz = Double(hz) / 1_000_000_000
        return ghz >= 1 ? String(format: "%.1fG", ghz)
                        : String(format: "%.0fM", Double(hz) / 1_000_000)
    }
}

// MARK: - GPU engine grid

private struct EngineGridView: View {
    var engines: [String: Double]

    private var sorted: [(key: String, value: Double)] {
        engines.sorted { $0.key < $1.key }
    }

    private var effectiveColumns: Int { min(sorted.count, 8) }

    private var barWidth: CGFloat {
        (BarMetrics.contentWidth - BarMetrics.spacing * CGFloat(effectiveColumns - 1)) / CGFloat(effectiveColumns)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: BarMetrics.spacing) {
            ForEach(sorted, id: \.key) { item in
                VStack(spacing: 1) {
                    BarView(width: barWidth, color: .purple, value: item.value)
                    Text(abbreviate(item.key))
                        .foregroundStyle(.secondary)
                    Text("\(Int(item.value))%")
                }
                .font(.system(size: 7))
                .monospacedDigit()
            }
        }
    }

    // Single-word → first 4 chars. Multi-word → uppercased initials.
    private func abbreviate(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count == 1 { return String(words[0].prefix(4)) }
        return words.map { String($0.prefix(1).uppercased()) }.joined()
    }
}

// MARK: - Shared helpers

@MainActor
private func detailToolbar(_ title: String) -> some View {
    HStack(spacing: 8) {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
        Spacer()
        Button { openSettings() } label: {
            Image(systemName: "gearshape")
        }
        .help("Settings")
        Button { NSApplication.shared.terminate(nil) } label: {
            Image(systemName: "power")
        }
        .help("Quit StatsMonitor")
    }
    .buttonStyle(.plain)
    .foregroundStyle(.secondary)
    .font(.system(size: 14))
}

private func sectionHeader(_ title: String) -> some View {
    Group {
        Divider()
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
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
