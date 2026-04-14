import SwiftUI

// MARK: - Main menu view (overview + navigation)

enum StatPanel { case cpu, gpu, memory, disk, network }

struct StatsMenuView: View {
    var viewModel: StatsViewModel
    @State private var selected: StatPanel? = nil

    var body: some View {
        switch selected {
        case .cpu:
            CPUDetailView(viewModel: viewModel, onBack: { selected = nil })
        case .gpu:
            GPUDetailView(viewModel: viewModel, onBack: { selected = nil })
        case .memory:
            MemoryDetailView(viewModel: viewModel, onBack: { selected = nil })
        case .disk:
            DiskDetailView(viewModel: viewModel, onBack: { selected = nil })
        case .network:
            NetworkDetailView(viewModel: viewModel, onBack: { selected = nil })
        case .none:
            StatsOverviewView(viewModel: viewModel, onSelect: { selected = $0 })
        }
    }
}

// MARK: - Overview (5 rows)

private struct StatsOverviewView: View {
    var viewModel: StatsViewModel
    var onSelect: (StatPanel) -> Void

    var body: some View {
        VStack(spacing: 0) {
            overviewToolbar()
            Divider()
            overviewRow("cpu",           "CPU",     viewModel.cpuPercent,    .blue,   .cpu)
            Divider()
            overviewRow("display",       "GPU",     viewModel.gpuPercent,    .purple, .gpu)
            Divider()
            overviewRow("memorychip",    "Memory",  viewModel.memoryPercent, .orange, .memory)
            Divider()
            overviewRow("internaldrive", "Disk",    viewModel.diskPercent,   .yellow, .disk)
            Divider()
            overviewRow("network",       "Network", "↓\(viewModel.networkIn)", .green, .network)
        }
        .frame(width: 280)
    }

    private func overviewRow(_ icon: String, _ label: String, _ value: String,
                              _ color: Color, _ panel: StatPanel) -> some View {
        Button { onSelect(panel) } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 18)
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                Text(value)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private func overviewToolbar() -> some View {
    HStack(spacing: 8) {
        Text("Stats")
            .font(.system(size: 13, weight: .semibold))
        Spacer()
        Button { openSettings() } label: { Image(systemName: "gearshape") }
            .help("Settings")
        Button { NSApplication.shared.terminate(nil) } label: { Image(systemName: "power") }
            .help("Quit StatsMonitor")
    }
    .buttonStyle(.plain)
    .foregroundStyle(.secondary)
    .font(.system(size: 14))
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
}

// MARK: - CPU Detail

struct CPUDetailView: View {
    var viewModel: StatsViewModel
    var onBack: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                detailToolbar("CPU", back: onBack)
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
                    Divider()
                    Text("Per Core")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    CoreGridView(cores: viewModel.cpuPerCore,
                                 frequencies: viewModel.cpuCoreFrequencies)
                }

                if !viewModel.topCPUProcesses.isEmpty {
                    Divider()
                    Text("Top Processes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(Array(viewModel.topCPUProcesses.enumerated()), id: \.offset) { _, proc in
                        statRow(proc.name, value: viewModel.formatProcessCPU(proc.cpuPercent))
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 280, height: 520)
    }
}

// MARK: - GPU Detail

struct GPUDetailView: View {
    var viewModel: StatsViewModel
    var onBack: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                detailToolbar("GPU", back: onBack)
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
                    Divider()
                    Text("Engines")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    EngineGridView(engines: viewModel.gpuEngines)
                }
            }
            .padding(16)
        }
        .frame(width: 280, height: 420)
    }
}

// MARK: - Memory Detail

struct MemoryDetailView: View {
    var viewModel: StatsViewModel
    var onBack: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                detailToolbar("Memory", back: onBack)
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
                    Divider()
                    Text("Top Processes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(Array(viewModel.topMemoryProcesses.enumerated()), id: \.offset) { _, proc in
                        statRow(proc.name, value: viewModel.formatProcessMemory(proc.memoryBytes))
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 280, height: 520)
    }
}

// MARK: - Disk Detail

struct DiskDetailView: View {
    var viewModel: StatsViewModel
    var onBack: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                detailToolbar("Disk", back: onBack)
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
                    Divider()
                    Text("Top Processes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(Array(viewModel.topDiskProcesses.enumerated()), id: \.offset) { _, proc in
                        statRow(proc.name, value: "↓\(viewModel.formatProcessDisk(proc.diskReadBPS)) ↑\(viewModel.formatProcessDisk(proc.diskWriteBPS))")
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 280, height: 520)
    }
}

// MARK: - Network Detail

struct NetworkDetailView: View {
    var viewModel: StatsViewModel
    var onBack: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                detailToolbar("Network", back: onBack)
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
                    Divider()
                    Text("Top Processes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(Array(viewModel.topNetworkProcesses.enumerated()), id: \.offset) { _, proc in
                        statRow(proc.name, value: "↓\(viewModel.formatProcessNetwork(proc.networkInBPS)) ↑\(viewModel.formatProcessNetwork(proc.networkOutBPS))")
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 280, height: 420)
    }
}

// MARK: - Vertical core grid

private struct CoreGridView: View {
    var cores: [Double]
    var frequencies: [CPUCoreFrequency] = []

    // frame width 280 – padding 16*2 = 248
    private let contentWidth: CGFloat = 248
    private let spacing: CGFloat      = 4
    private let barHeight: CGFloat    = 48

    /// ≤10 cores → fill the full row; >10 → always use 10-column width
    private var effectiveColumns: Int { min(cores.count, 10) }

    private var barWidth: CGFloat {
        (contentWidth - spacing * CGFloat(effectiveColumns - 1)) / CGFloat(effectiveColumns)
    }

    private var rows: [[(index: Int, value: Double)]] {
        let items = cores.enumerated().map { (index: $0.offset, value: $0.element) }
        return stride(from: 0, to: items.count, by: effectiveColumns).map {
            Array(items[$0 ..< min($0 + effectiveColumns, items.count)])
        }
    }

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
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(row, id: \.index) { item in
                        let freq = item.index < frequencies.count ? frequencies[item.index] : .zero
                        VStack(spacing: 1) {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(width: barWidth, height: barHeight)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(barColor(for: item.index))
                                    .frame(width: barWidth, height: max(2, barHeight * item.value / 100))
                            }
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

    private let contentWidth: CGFloat = 248
    private let spacing: CGFloat      = 4
    private let barHeight: CGFloat    = 48

    private var sorted: [(key: String, value: Double)] {
        engines.sorted { $0.key < $1.key }
    }

    private var effectiveColumns: Int { min(sorted.count, 8) }

    private var barWidth: CGFloat {
        (contentWidth - spacing * CGFloat(effectiveColumns - 1)) / CGFloat(effectiveColumns)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(sorted, id: \.key) { item in
                VStack(spacing: 1) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: barWidth, height: barHeight)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.purple)
                            .frame(width: barWidth, height: max(2, barHeight * item.value / 100))
                    }
                    Text(abbreviate(item.key))
                        .foregroundStyle(.secondary)
                    Text("\(Int(item.value))%")
                }
                .font(.system(size: 7))
                .monospacedDigit()
            }
        }
    }

    private func abbreviate(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count == 1 { return String(words[0].prefix(4)) }
        return words.map { String($0.prefix(1).uppercased()) }.joined()
    }
}

// MARK: - Shared helpers

@MainActor
private func detailToolbar(_ title: String, back: (() -> Void)? = nil) -> some View {
    HStack(spacing: 8) {
        if let back {
            Button(action: back) {
                Image(systemName: "chevron.left")
            }
            .help("Back")
        }
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
