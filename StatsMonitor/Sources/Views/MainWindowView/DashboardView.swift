import SwiftUI

// MARK: - DashboardView

struct DashboardView: View {
    let settings: AppSettings
    var monitor: SystemMonitor

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: settings.dashboardColumns)
    }

    private func histMax(_ h: [Double]) -> Double {
        max(h.max() ?? 0, 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(columns: columns, spacing: 4) {
                    MetricChartCard(
                        title: "CPU",
                        value: monitor.cpuPercent,
                        statusColor: progressColor(monitor.cpuFraction),
                        lines: [(history: monitor.paddedCPUHistory, color: .blue)],
                        maxValue: histMax(monitor.paddedCPUHistory)
                    )
                    MetricChartCard(
                        title: "GPU",
                        value: monitor.gpuPercent,
                        statusColor: progressColor(monitor.gpuFraction),
                        lines: [(history: monitor.paddedGPUHistory, color: .purple)],
                        maxValue: histMax(monitor.paddedGPUHistory)
                    )
                    MetricChartCard(
                        title: "Memory",
                        value: monitor.memoryPercent,
                        statusColor: progressColor(monitor.memoryFraction),
                        lines: [(history: monitor.paddedMemoryHistory, color: .cyan)],
                        maxValue: histMax(monitor.paddedMemoryHistory)
                    )
                    MetricChartCard(
                        title: "Network",
                        value: "↓\(monitor.networkInText)  ↑\(monitor.networkOutText)",
                        statusColor: .blue,
                        lines: [
                            (history: monitor.paddedNetworkInHistory,  color: .blue),
                            (history: monitor.paddedNetworkOutHistory, color: .green),
                        ],
                        maxValue: histMax(monitor.paddedNetworkInHistory + monitor.paddedNetworkOutHistory)
                    )
                    MetricChartCard(
                        title: "Disk I/O",
                        value: "↓\(monitor.diskReadText)  ↑\(monitor.diskWriteText)",
                        statusColor: .blue,
                        lines: [
                            (history: monitor.paddedDiskReadHistory,  color: .teal),
                            (history: monitor.paddedDiskWriteHistory, color: .orange),
                        ],
                        maxValue: histMax(monitor.paddedDiskReadHistory + monitor.paddedDiskWriteHistory)
                    )
                    if monitor.hasPower {
                        MetricChartCard(
                            title: "Power",
                            value: monitor.powerText,
                            statusColor: powerStatusColor(monitor.power?.totalWatts ?? 0),
                            lines: [(history: monitor.paddedPowerHistory, color: .red)],
                            maxValue: histMax(monitor.paddedPowerHistory)
                        )
                    }
                    if monitor.hasFans {
                        MetricChartCard(
                            title: "Fans",
                            value: monitor.fansSummaryText,
                            statusColor: .blue,
                            lines: monitor.paddedFanAverageHistory.count >= 2
                                ? [(history: monitor.paddedFanAverageHistory, color: .blue)]
                                : [],
                            maxValue: monitor.fanChartMaxRPM
                        )
                    }
                }

                DashboardProcessTable(settings: settings, monitor: monitor)
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                DashboardColumnsSlider(settings: settings)
            }
        }
    }
}

struct DashboardColumnsSlider: View {
    let settings: AppSettings
    private static let valueRange = Double(AppSettings.dashboardColumnRange.lowerBound)...Double(AppSettings.dashboardColumnRange.upperBound)

    static func binding(for settings: AppSettings) -> Binding<Double> {
        Binding(
            get: { Double(settings.dashboardColumns) },
            set: { newValue in
                let clampedValue = min(max(newValue, valueRange.lowerBound), valueRange.upperBound)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    settings.dashboardColumns = Int(clampedValue.rounded())
                }
            }
        )
    }

    var body: some View {
        Slider(value: Self.binding(for: settings), in: Self.valueRange, step: 1)
            .frame(width: 110)
    }
}

// MARK: - Dashboard Helpers

private func powerStatusColor(_ watts: Double) -> Color {
    switch watts {
    case ..<10:
        return .green
    case ..<30:
        return .orange
    default:
        return .red
    }
}

func dashboardCardHasChart(lines: [(history: [Double], color: Color)]) -> Bool {
    !lines.isEmpty
}

func dashboardCardHeight(lines: [(history: [Double], color: Color)]) -> CGFloat {
    dashboardCardHasChart(lines: lines) ? 100 : 52
}

// MARK: - DashboardProcessTable

private struct DashboardProcessTable: View {
    let settings: AppSettings
    var monitor: SystemMonitor

    enum SortColumn { case name, cpu, memory, disk, network }

    @State private var sortColumn: SortColumn = .cpu
    @State private var ascending: Bool = false

    private var mergedProcesses: [ProcInfo] {
        var byName: [String: ProcInfo] = [:]
        let all = monitor.topCPUProcesses
            + monitor.topMemoryProcesses
            + monitor.topDiskProcesses
            + monitor.topNetworkProcesses
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
        return Array(byName.values).sorted(using: sortColumn, ascending: ascending)
    }

    private func toggleSort(_ col: SortColumn) {
        if sortColumn == col { ascending.toggle() } else { sortColumn = col; ascending = false }
    }

    @ViewBuilder
    private func colHeader(_ label: LocalizedStringKey, col: SortColumn, width: CGFloat) -> some View {
        Button { toggleSort(col) } label: {
            HStack(spacing: 2) {
                Spacer(minLength: 0)
                Text(label)
                Image(systemName: ascending ? "chevron.up" : "chevron.down")
                    .imageScale(.small)
                    .opacity(sortColumn == col ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .frame(width: width, alignment: .trailing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Processes")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(spacing: 0) {
                HStack {
                    Button { toggleSort(.name) } label: {
                        HStack(spacing: 2) {
                            Text("Name")
                            Image(systemName: ascending ? "chevron.up" : "chevron.down")
                                .imageScale(.small)
                                .opacity(sortColumn == .name ? 1 : 0)
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    colHeader("CPU%",    col: .cpu,     width: 60)
                    colHeader("Memory",  col: .memory,  width: 72)
                    colHeader("Disk",    col: .disk,    width: 72)
                    colHeader("Network", col: .network, width: 80)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)

                Divider()

                ForEach(
                    Array(mergedProcesses.prefix(settings.processCount)),
                    id: \.name
                ) { proc in
                    HStack {
                        Text(proc.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(monitor.formatProcessCPU(proc.cpuPercent))
                            .frame(width: 60, alignment: .trailing)
                        Text(monitor.formatProcessMemory(proc.memoryBytes))
                            .frame(width: 72, alignment: .trailing)
                        Text(proc.diskTotalBPS > 0
                             ? monitor.formatProcessDisk(proc.diskTotalBPS) : "—")
                            .frame(width: 72, alignment: .trailing)
                        Text(proc.networkTotalBPS > 0
                             ? monitor.formatProcessNetwork(proc.networkTotalBPS) : "—")
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

// MARK: - ProcInfo sort helper

private extension Array where Element == ProcInfo {
    func sorted(using col: DashboardProcessTable.SortColumn, ascending: Bool) -> [ProcInfo] {
        sorted { a, b in
            let less: Bool
            switch col {
            case .name:    less = a.name < b.name
            case .cpu:     less = a.cpuPercent < b.cpuPercent
            case .memory:  less = a.memoryBytes < b.memoryBytes
            case .disk:    less = a.diskTotalBPS < b.diskTotalBPS
            case .network: less = a.networkTotalBPS < b.networkTotalBPS
            }
            return ascending ? less : !less
        }
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    let settings = AppSettings()
    let monitor = SystemMonitor(settings: settings).start()
    DashboardView(settings: settings, monitor: monitor)
        .frame(width: 820, height: 520)
}
