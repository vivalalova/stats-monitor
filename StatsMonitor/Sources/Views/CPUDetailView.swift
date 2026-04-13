import SwiftUI

// MARK: - Panel exclusion

extension Notification.Name {
    static let panelOpened = Notification.Name("StatsMonitorPanelOpened")
}

// MARK: - CPU Detail

struct CPUDetailView: View {
    var viewModel: StatsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.cpuHistory.count >= 2 {
                LineChartView(history: viewModel.cpuHistory, color: .blue)
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

            Divider()
            quitButton()
        }
        .padding(16)
        .frame(width: 280)
        .onAppear { NotificationCenter.default.post(name: .panelOpened, object: "cpu") }
        .onReceive(NotificationCenter.default.publisher(for: .panelOpened)) { note in
            if note.object as? String != "cpu" { dismiss() }
        }
    }
}

// MARK: - GPU Detail

struct GPUDetailView: View {
    var viewModel: StatsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.gpuHistory.count >= 2 {
                LineChartView(history: viewModel.gpuHistory, color: .purple)
            }

            statRow("Device",   value: viewModel.gpuPercent)
            statRow("Renderer", value: viewModel.gpuRenderPercent)
            ProgressView(value: viewModel.monitor.stats.gpu.used / 100)
                .tint(progressColor(viewModel.monitor.stats.gpu.used / 100))

            let sortedEngines = viewModel.gpuEngines
                .sorted { $0.key < $1.key }
                .filter { $0.key != "Device" && $0.key != "Renderer" }

            if !sortedEngines.isEmpty {
                Divider()
                Text("Engines")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(sortedEngines, id: \.key) { key, val in
                    HStack(spacing: 8) {
                        Text(key)
                            .foregroundStyle(.secondary)
                        Spacer()
                        ProgressView(value: val / 100)
                            .frame(width: 80)
                            .tint(progressColor(val / 100))
                        Text(String(format: "%.0f%%", val))
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                    .font(.system(size: 12))
                }
            }

            Divider()
            quitButton()
        }
        .padding(16)
        .frame(width: 280)
        .onAppear { NotificationCenter.default.post(name: .panelOpened, object: "gpu") }
        .onReceive(NotificationCenter.default.publisher(for: .panelOpened)) { note in
            if note.object as? String != "gpu" { dismiss() }
        }
    }
}

// MARK: - Memory Detail

struct MemoryDetailView: View {
    var viewModel: StatsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.memoryHistory.count >= 2 {
                LineChartView(history: viewModel.memoryHistory, color: .orange)
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

            Divider()
            quitButton()
        }
        .padding(16)
        .frame(width: 280)
        .onAppear { NotificationCenter.default.post(name: .panelOpened, object: "memory") }
        .onReceive(NotificationCenter.default.publisher(for: .panelOpened)) { note in
            if note.object as? String != "memory" { dismiss() }
        }
    }
}

// MARK: - Disk Detail

struct DiskDetailView: View {
    var viewModel: StatsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.diskHistory.count >= 2 {
                LineChartView(history: viewModel.diskHistory, color: .yellow)
            }

            statRow("Used",  value: viewModel.diskUsed)
            statRow("Free",  value: viewModel.diskFree)
            statRow("Total", value: viewModel.diskTotal)
            ProgressView(value: viewModel.monitor.stats.disk.usedFraction)
                .tint(progressColor(viewModel.monitor.stats.disk.usedFraction))

            Divider()
            quitButton()
        }
        .padding(16)
        .frame(width: 280)
        .onAppear { NotificationCenter.default.post(name: .panelOpened, object: "disk") }
        .onReceive(NotificationCenter.default.publisher(for: .panelOpened)) { note in
            if note.object as? String != "disk" { dismiss() }
        }
    }
}

// MARK: - Network Detail

struct NetworkDetailView: View {
    var viewModel: StatsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let maxVal = max(
                (viewModel.networkInHistory + viewModel.networkOutHistory).max() ?? 1,
                1_048_576
            )

            if viewModel.networkInHistory.count >= 2 {
                Text("Download")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LineChartView(history: viewModel.networkInHistory, maxValue: maxVal, color: .green)
            }

            if viewModel.networkOutHistory.count >= 2 {
                Text("Upload")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LineChartView(history: viewModel.networkOutHistory, maxValue: maxVal, color: .red)
            }

            statRow("↓ In",  value: viewModel.networkIn)
            statRow("↑ Out", value: viewModel.networkOut)

            Divider()
            quitButton()
        }
        .padding(16)
        .frame(width: 280)
        .onAppear { NotificationCenter.default.post(name: .panelOpened, object: "network") }
        .onReceive(NotificationCenter.default.publisher(for: .panelOpened)) { note in
            if note.object as? String != "network" { dismiss() }
        }
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
                                    .fill(progressColor(item.value / 100))
                                    .frame(width: barWidth, height: max(2, barHeight * item.value / 100))
                            }
                            Text("C\(item.index)")
                                .foregroundStyle(.secondary)
                            if freq.maxHz > 0 {
                                if freq.currentHz > 0 {
                                    Text(ghzString(freq.currentHz))
                                }
                                Text(ghzString(freq.maxHz))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(Int(item.value))%")
                            }
                        }
                        .font(.system(size: 7))
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
