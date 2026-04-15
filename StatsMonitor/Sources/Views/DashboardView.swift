import SwiftUI

// MARK: - DashboardView

struct DashboardView: View {
    var viewModel: StatsViewModel

    private var settings: AppSettings { viewModel.settings }

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
                    MetricCard(
                        title: "CPU",
                        value: viewModel.cpuPercent,
                        statusColor: progressColor(viewModel.cpuFraction),
                        lines: [(history: viewModel.cpuHistory, color: .blue)],
                        maxValue: histMax(viewModel.cpuHistory)
                    )
                    MetricCard(
                        title: "GPU",
                        value: viewModel.gpuPercent,
                        statusColor: progressColor(viewModel.gpuFraction),
                        lines: [(history: viewModel.gpuHistory, color: .purple)],
                        maxValue: histMax(viewModel.gpuHistory)
                    )
                    MetricCard(
                        title: "Memory",
                        value: viewModel.memoryPercent,
                        statusColor: progressColor(viewModel.memoryFraction),
                        lines: [(history: viewModel.memoryHistory, color: .cyan)],
                        maxValue: histMax(viewModel.memoryHistory)
                    )
                    MetricCard(
                        title: "Disk",
                        value: viewModel.diskPercent,
                        statusColor: progressColor(viewModel.diskFraction),
                        lines: [],
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
                        maxValue: histMax(viewModel.networkInHistory + viewModel.networkOutHistory)
                    )
                    if viewModel.hasBattery {
                        MetricCard(
                            title: "Battery",
                            value: "\(viewModel.batteryPercent)  \(viewModel.batteryStatus)",
                            statusColor: batteryStatusColor(viewModel.battery),
                            lines: viewModel.batteryHistory.count >= 2
                                ? [(history: viewModel.batteryHistory, color: .green)]
                                : [],
                            maxValue: histMax(viewModel.batteryHistory)
                        )
                    }
                    if viewModel.hasThermal {
                        MetricCard(
                            title: "Thermal",
                            value: "CPU \(viewModel.cpuTempStr)",
                            statusColor: thermalStatusColor(viewModel.thermal?.cpuTemperature ?? 0),
                            lines: viewModel.cpuTempHistory.count >= 2
                                ? [(history: viewModel.cpuTempHistory, color: .orange)]
                                : [],
                            maxValue: histMax(viewModel.cpuTempHistory)
                        )
                    }
                    MetricCard(
                        title: "Disk I/O",
                        value: "↓\(viewModel.diskRead)  ↑\(viewModel.diskWrite)",
                        statusColor: .blue,
                        lines: [
                            (history: viewModel.diskReadHistory,  color: .teal),
                            (history: viewModel.diskWriteHistory, color: .orange),
                        ],
                        maxValue: histMax(viewModel.diskReadHistory + viewModel.diskWriteHistory)
                    )
                    if viewModel.hasPower {
                        MetricCard(
                            title: "Power",
                            value: viewModel.powerStr,
                            statusColor: powerStatusColor(viewModel.power?.totalWatts ?? 0),
                            lines: [(history: viewModel.powerHistory, color: .red)],
                            maxValue: histMax(viewModel.powerHistory)
                        )
                    }
                    if viewModel.hasFans {
                        MetricCard(
                            title: "Fans",
                            value: viewModel.fansSummary,
                            statusColor: .blue,
                            lines: [],
                            maxValue: 100
                        )
                    }
                }

                DashboardProcessTable(viewModel: viewModel)
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

private func batteryStatusColor(_ battery: BatteryUsage?) -> Color {
    guard let b = battery else { return .gray }
    if b.isCharging { return .green }
    return progressColor(1.0 - b.percentage / 100.0)  // low charge → red
}

private func powerStatusColor(_ watts: Double) -> Color {
    switch watts {
    case ..<10:  .green
    case ..<30:  .orange
    default:     .red
    }
}

private func thermalStatusColor(_ celsius: Double) -> Color {
    switch celsius {
    case ..<60:  .green
    case ..<80:  .orange
    default:     .red
    }
}

// MARK: - MetricCard

private struct MetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let statusColor: Color
    let lines: [(history: [Double], color: Color)]
    let maxValue: Double

    var body: some View {
        ZStack(alignment: .topLeading) {
            LineChartView(lines: lines, maxValue: maxValue, height: nil, cornerRadius: 8)

            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .shadow(color: .white.opacity(0.7), radius: 3, x: 0, y: 0)
                Spacer()
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            .padding(4)

            VStack {
                Spacer()
                HStack {
                    Text(value)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .shadow(color: .white.opacity(0.7), radius: 3, x: 0, y: 0)
                    Spacer()
                }
            }
            .padding(4)
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - DashboardProcessTable

private struct DashboardProcessTable: View {
    var viewModel: StatsViewModel

    enum SortColumn { case name, cpu, memory, disk, network }

    @State private var sortColumn: SortColumn = .cpu
    @State private var ascending: Bool = false

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
    DashboardView(viewModel: StatsViewModel())
        .frame(width: 820, height: 520)
}
